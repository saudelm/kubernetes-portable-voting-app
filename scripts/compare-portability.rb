#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "open3"
require "time"
require "yaml"

ROOT = File.expand_path("..", __dir__)
CHART = File.join(ROOT, "charts", "voting-app")
EVIDENCE = File.join(ROOT, "evidence")
ABSENT = "<absent>"

def render(values_file, overrides = [])
  command = [
    "helm", "template", "voting", CHART,
    "--namespace", "voting",
    "--values", values_file
  ]
  overrides.each { |override| command.concat(["--set-string", override]) }
  stdout, stderr, status = Open3.capture3(*command)
  raise "Helm rendering failed: #{stderr}" unless status.success?

  YAML.load_stream(stdout).compact
end

def identity(document)
  metadata = document.fetch("metadata", {})
  namespace = metadata.fetch("namespace", "voting")
  "#{document.fetch('kind', '<unknown>')}/#{namespace}/#{metadata.fetch('name', '<unnamed>')}"
end

def flatten(value, prefix = "", output = {})
  case value
  when Hash
    value.keys.sort.each do |key|
      path = prefix.empty? ? key.to_s : "#{prefix}.#{key}"
      flatten(value[key], path, output)
    end
  when Array
    value.each_with_index { |item, index| flatten(item, "#{prefix}[#{index}]", output) }
  else
    output[prefix] = value
  end
  output
end

def category(path)
  return "replica_count" if path.end_with?(".spec.replicas")
  return "image_reference" if path.include?(".spec.template.spec.containers[") && path.end_with?(".image")
  return "external_hostname" if path.include?(".spec.rules[") && path.end_with?(".host")
  return "storage_class" if path.include?(".volumeClaimTemplates[") && path.end_with?(".storageClassName")
  return "platform_networking" if path.start_with?("NetworkPolicy/voting/voting-voting-app-allow-dns.") ||
                                  path.start_with?("NetworkPolicy/voting/voting-voting-app-allow-ingress-to-web.")

  nil
end

def compare(local_documents, gke_documents)
  local_objects = local_documents.to_h { |document| [identity(document), document] }
  gke_objects = gke_documents.to_h { |document| [identity(document), document] }
  local_ids = local_objects.keys
  gke_ids = gke_objects.keys
  shared_ids = local_ids & gke_ids
  union_ids = local_ids | gke_ids
  differences = []
  same_leaf_values = 0
  total_leaf_slots = 0

  shared_ids.sort.each do |object_id|
    local_flat = flatten(local_objects.fetch(object_id))
    gke_flat = flatten(gke_objects.fetch(object_id))
    paths = local_flat.keys | gke_flat.keys
    total_leaf_slots += paths.length

    paths.sort.each do |path|
      local_value = local_flat.fetch(path, ABSENT)
      gke_value = gke_flat.fetch(path, ABSENT)
      if local_value == gke_value
        same_leaf_values += 1
        next
      end

      difference_category = category("#{object_id}.#{path}")
      differences << {
        "object" => object_id,
        "path" => path,
        "local" => local_value,
        "gke" => gke_value,
        "category" => difference_category || "unexpected",
        "expected" => !difference_category.nil?
      }
    end
  end

  unexpected = differences.reject { |difference| difference.fetch("expected") }
  shared_ratio = union_ids.empty? ? 1.0 : shared_ids.length.to_f / union_ids.length
  leaf_reuse_ratio = total_leaf_slots.zero? ? 1.0 : same_leaf_values.to_f / total_leaf_slots

  {
    "generated_at_utc" => Time.now.utc.iso8601,
    "method" => "Static comparison of Helm-rendered Kubernetes manifests; no runtime result.",
    "metrics" => {
      "local_object_count" => local_ids.length,
      "gke_object_count" => gke_ids.length,
      "shared_object_count" => shared_ids.length,
      "shared_object_ratio" => shared_ratio.round(6),
      "same_leaf_value_count" => same_leaf_values,
      "compared_leaf_slot_count" => total_leaf_slots,
      "leaf_value_reuse_ratio" => leaf_reuse_ratio.round(6),
      "expected_difference_count" => differences.length - unexpected.length,
      "unexpected_difference_count" => unexpected.length
    },
    "objects_only_local" => (local_ids - gke_ids).sort,
    "objects_only_gke" => (gke_ids - local_ids).sort,
    "differences" => differences
  }
end

def markdown(report)
  metrics = report.fetch("metrics")
  lines = [
    "# Statische Portabilitaetsanalyse",
    "",
    "Erzeugt (UTC): `#{report.fetch('generated_at_utc')}`",
    "",
    "> Diese Auswertung vergleicht gerenderte Manifeste. Sie ist kein Nachweis einer erfolgreichen Laufzeitbereitstellung.",
    "",
    "## Kennzahlen",
    "",
    "| Kennzahl | Wert |",
    "|---|---:|",
    "| Objekte lokal | #{metrics.fetch('local_object_count')} |",
    "| Objekte GKE | #{metrics.fetch('gke_object_count')} |",
    "| Identische Objektidentitaeten | #{metrics.fetch('shared_object_count')} |",
    format("| Objektwiederverwendung | %.2f%% |", metrics.fetch("shared_object_ratio") * 100),
    format("| Wiederverwendete Blattwerte | %.2f%% |", metrics.fetch("leaf_value_reuse_ratio") * 100),
    "| Erwartete Umgebungsunterschiede | #{metrics.fetch('expected_difference_count')} |",
    "| Unerwartete Unterschiede | #{metrics.fetch('unexpected_difference_count')} |",
    "",
    "## Umgebungsunterschiede",
    "",
    "| Objekt | Feld | Kategorie | Lokal | GKE |",
    "|---|---|---|---|---|"
  ]

  report.fetch("differences").each do |difference|
    lines << "| `#{difference.fetch('object')}` | `#{difference.fetch('path')}` | " \
             "#{difference.fetch('category')} | `#{JSON.generate(difference.fetch('local'))}` | " \
             "`#{JSON.generate(difference.fetch('gke'))}` |"
  end
  lines << "| - | - | - | - | - |" if report.fetch("differences").empty?
  lines.concat([
    "",
    "## Interpretation",
    "",
    "Die Objektidentitaeten muessen vollstaendig uebereinstimmen. Abweichungen sind nur fuer Replikate, Image-Referenzen, externe Hostnamen, die StorageClass und explizite Plattform-Netzwerkregeln vorgesehen. Ein Laufzeitnachweis fuer K3d und GKE wird getrennt erhoben.",
    ""
  ])
  lines.join("\n")
end

gke_overrides = [
  "vote.image.tag=abcdef1",
  "result.image.tag=abcdef1",
  "worker.image.tag=abcdef1",
  "vote.ingress.host=vote.192.0.2.1.nip.io",
  "result.ingress.host=result.192.0.2.1.nip.io",
  "networkPolicy.allowNodeLocalDns=true",
  "networkPolicy.healthProbeCidrs[0]=169.254.4.6/32"
]

report = compare(
  render(File.join(CHART, "values.yaml")),
  render(File.join(CHART, "values-gke.yaml"), gke_overrides)
)

Dir.mkdir(EVIDENCE) unless Dir.exist?(EVIDENCE)
File.write(File.join(EVIDENCE, "portability-comparison.json"), JSON.pretty_generate(report) + "\n")
File.write(File.join(EVIDENCE, "portability-comparison.md"), markdown(report))

metrics = report.fetch("metrics")
puts "Portability comparison: #{metrics.fetch('shared_object_count')} shared objects, " \
     "#{metrics.fetch('unexpected_difference_count')} unexpected differences."

exit 1 unless report.fetch("objects_only_local").empty? &&
              report.fetch("objects_only_gke").empty? &&
              metrics.fetch("unexpected_difference_count").zero?
