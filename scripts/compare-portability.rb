#!/usr/bin/env ruby
# frozen_string_literal: true
require "json"
require "open3"
require "optparse"
require "fileutils"
require "time"
require "yaml"

module Portability
  ROOT = File.expand_path("..", __dir__)
  CHART = File.join(ROOT, "charts", "voting-app")
  ABSENT = Object.new.freeze
  TAG = "abcdef1"
  PROBE_CIDR = "169.254.4.6/32"

  def self.render(target)
    args = ["helm", "template", "voting", CHART, "--namespace", "voting",
            "--set-string", "postgres.password=static-test-not-a-credential"]
    if target == "gke"
      args += ["-f", File.join(CHART, "values-gke.yaml")]
      %w[vote result worker].each { |c| args += ["--set-string", "#{c}.image.tag=#{TAG}"] }
      %w[vote result].each { |c| args += ["--set-string", "#{c}.ingress.host=#{c}.192.0.2.1.nip.io"] }
      args += ["--set-string", "networkPolicy.healthProbeCidrs[0]=#{PROBE_CIDR}"]
    end
    stdout, stderr, status = Open3.capture3(*args)
    raise "Helm rendering failed: #{stderr}" unless status.success?

    parse_documents(stdout)
  end

  def self.check_yaml_node(node)
    if node.is_a?(Psych::Nodes::Mapping)
      keys = node.children.each_slice(2).map do |key, _|
        raise "Only scalar YAML mapping keys are supported" unless key.is_a?(Psych::Nodes::Scalar)
        key.value
      end
      raise "Duplicate YAML mapping key" unless keys.uniq.length == keys.length
    end
    Array(node.children).each { |child| check_yaml_node(child) }
  end

  def self.parse_documents(text)
    YAML.parse_stream(text).children.map do |document|
      check_yaml_node(document)
      # A stream wrapper is required by the Psych emitter on macOS Ruby 2.6.
      stream = Psych::Nodes::Stream.new
      stream.children << document
      YAML.safe_load(stream.to_yaml, permitted_classes: [], permitted_symbols: [], aliases: false)
    end.compact
  end

  def self.identity(document)
    metadata = document.fetch("metadata")
    [document.fetch("apiVersion"), document.fetch("kind"),
     metadata.fetch("namespace", "voting"), metadata.fetch("name")].join("|")
  end

  def self.index(documents)
    documents.each_with_object({}) do |document, result|
      id = identity(document)
      raise "Duplicate Kubernetes identity: #{id}" if result.key?(id)

      result[id] = document
    end
  end

  # JSON Pointer preserves key boundaries. Empty maps/lists are values, not nothing.
  def self.flatten(value, prefix = "", output = {})
    case value
    when Hash
      output[prefix] = {} if value.empty?
      value.each do |key, item|
        raise "YAML mapping keys must be strings" unless key.is_a?(String)
        escaped = key.gsub("~", "~0").gsub("/", "~1")
        flatten(item, "#{prefix}/#{escaped}", output)
      end
    when Array
      output[prefix] = [] if value.empty?
      value.each_with_index { |item, i| flatten(item, "#{prefix}/#{i}", output) }
    else
      output[prefix] = value
    end
    output
  end

  def self.container_types(value, prefix = "", output = {})
    if value.is_a?(Hash)
      output[prefix] = "mapping"
      value.each do |key, item|
        escaped = key.gsub("~", "~0").gsub("/", "~1")
        container_types(item, "#{prefix}/#{escaped}", output)
      end
    elsif value.is_a?(Array)
      output[prefix] = "sequence"
      value.each_with_index { |item, i| container_types(item, "#{prefix}/#{i}", output) }
    end
    output
  end

  def self.rules
    result = {}
    %w[vote result worker].each do |c|
      key = ["apps/v1|Deployment|voting|voting-voting-app-#{c}", "/spec/template/spec/containers/0/image"]
      result[key] = ["voting-#{c}:local", "ghcr.io/saudelm/kubernetes-portable-voting-app/#{c}:#{TAG}",
                     "Umgebungsparameter", "Image-Referenz", "Commit -> Build -> Laufzeit-Image je CPU-Architektur"]
    end
    %w[vote result].each_with_index do |c, i|
      key = ["networking.k8s.io/v1|Ingress|voting|voting-voting-app", "/spec/rules/#{i}/host"]
      result[key] = ["#{c}.127.0.0.1.nip.io", "#{c}.192.0.2.1.nip.io",
                     "Umgebungsparameter", "DNS/Ingress", "HTTP und WebSocket ueber Ziel-Ingress"]
    end
    result[["apps/v1|StatefulSet|voting|voting-voting-app-postgres",
            "/spec/volumeClaimTemplates/0/spec/storageClassName"]] =
      [ABSENT, "standard-rwo", "Plattformintegration", "Storage", "PVC und T2; keine Datenmigration"]
    dns = "networking.k8s.io/v1|NetworkPolicy|voting|voting-voting-app-allow-dns"
    result[[dns, "/spec/egress/0/to/1/namespaceSelector/matchLabels/kubernetes.io~1metadata.name"]] =
      [ABSENT, "kube-system", "Plattformintegration", "NodeLocal DNS", "DNS im Zielcluster pruefen"]
    result[[dns, "/spec/egress/0/to/1/podSelector/matchLabels/k8s-app"]] =
      [ABSENT, "node-local-dns", "Plattformintegration", "NodeLocal DNS", "DNS im Zielcluster pruefen"]
    result[["networking.k8s.io/v1|NetworkPolicy|voting|voting-voting-app-allow-ingress-to-web",
            "/spec/ingress/0/from/1/ipBlock/cidr"]] =
      [ABSENT, PROBE_CIDR, "Plattformintegration", "GKE-Probe-Quelladresse",
       "Tatsaechliche Router-IP und Readiness; Beispieladresse allein kein Beleg"]
    result
  end

  def self.display(value)
    value.equal?(ABSENT) ? { "absent" => true } : { "value" => value }
  end

  def self.compare(local_documents, gke_documents)
    local = index(local_documents)
    gke = index(gke_documents)
    differences = []
    (local.keys & gke.keys).sort.each do |id|
      left = flatten(local.fetch(id))
      right = flatten(gke.fetch(id))
      left_types = container_types(local.fetch(id))
      right_types = container_types(gke.fetch(id))
      (left_types.keys & right_types.keys).sort.each do |path|
        next if left_types[path] == right_types[path]

        differences << {
          "object" => id, "path" => path, "local" => { "container_type" => left_types[path] },
          "gke" => { "container_type" => right_types[path] }, "expected" => false,
          "cause" => "Geaenderter YAML-Strukturtyp", "implementation" => "Einzelfallpruefung erforderlich",
          "required_evidence" => "Mapping und Sequenz sind nicht austauschbar"
        }
      end
      (left.keys | right.keys).sort.each do |path|
        a = left.fetch(path, ABSENT)
        b = right.fetch(path, ABSENT)
        next if a == b

        rule = rules[[id, path]]
        expected = !rule.nil? && rule[0] == a && rule[1] == b
        differences << {
          "object" => id, "path" => path, "local" => display(a), "gke" => display(b),
          "expected" => expected,
          "cause" => expected ? rule[2] : "Nicht freigegebene Abweichung",
          "implementation" => expected ? rule[3] : "Einzelfallpruefung erforderlich",
          "required_evidence" => expected ? rule[4] : "Ursache pruefen; nicht automatisch akzeptieren"
        }
      end
    end
    only_local = (local.keys - gke.keys).sort
    only_gke = (gke.keys - local.keys).sort
    {
      "generated_at_utc" => Time.now.utc.iso8601,
      "method" => "Statischer Vergleich festgelegter Beispielprofile, keine Portabilitaetsquote und kein Laufzeitnachweis.",
      "status" => only_local.empty? && only_gke.empty? && differences.all? { |d| d["expected"] } ? "PASS" : "FAIL",
      "object_counts" => { "local" => local.length, "gke" => gke.length },
      "objects_only_local" => only_local, "objects_only_gke" => only_gke, "differences" => differences
    }
  end

  def self.markdown(report)
    lines = ["# Anpassungsmatrix", "", report["method"], "", "Statisches Pruefergebnis: **#{report['status']}**", "",
             "| Objekt / Feld | Ursache | Umsetzung | Lokal -> GKE | Erforderlicher Nachweis |",
             "|---|---|---|---|---|"]
    report["differences"].each do |d|
      cells = ["#{d['object']} #{d['path']}", d["cause"], d["implementation"],
               "#{JSON.generate(d['local'])} -> #{JSON.generate(d['gke'])}", d["required_evidence"]]
      lines << "| #{cells.map { |s| s.gsub('|', '\\|') }.join(' | ')} |"
    end
    lines += ["", "Nur lokal: #{report['objects_only_local'].join(', ')}",
              "Nur GKE: #{report['objects_only_gke'].join(', ')}", "",
              "## Grenzen", "",
              "- Gleiche Replikate (2 Vote, 2 Result) sind eine freie Versuchsentscheidung.",
              "- Terraform, Cluster, Load Balancer und reale Images liegen ausserhalb dieses Chartvergleichs.",
              "- Gemeinsame Anwendungsaenderungen sind separat zu belegen.",
              "- Erwartete Unterschiede sind statisch erklaert, nicht zur Laufzeit bestaetigt.",
              "- Keine Aussage zu Datenmigration oder allgemeiner Hochverfuegbarkeit.", ""]
    lines.join("\n")
  end

  def self.main
    options = {}
    OptionParser.new { |p| p.on("--output DIR") { |v| options[:output] = v } }.parse!
    raise "Use --output with a NEW directory" unless options[:output]
    output = File.expand_path(options[:output])
    raise "Output already exists: #{output}" if File.exist?(output)
    report = compare(render("local"), render("gke"))
    FileUtils.mkdir_p(output)
    File.write(File.join(output, "adaptation-matrix.json"), JSON.pretty_generate(report) + "\n")
    File.write(File.join(output, "adaptation-matrix.md"), markdown(report))
    puts "#{report['status']}: #{report['differences'].length} field differences; no portability percentage."
    report["status"] == "PASS" ? 0 : 1
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    exit Portability.main
  rescue StandardError => e
    warn "ERROR: #{e.message}"
    exit 2
  end
end
