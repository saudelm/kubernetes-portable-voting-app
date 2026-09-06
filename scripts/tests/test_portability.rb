# frozen_string_literal: true
require "minitest/autorun"
require_relative "../compare-portability"

class PortabilityTest < Minitest::Test
  def setup
    @local = Portability.render("local")
    @gke = Portability.render("gke")
  end

  def report
    Portability.compare(@local, @gke)
  end

  def object(suffix)
    @gke.find { |d| d.dig("metadata", "name") == "voting-voting-app-#{suffix}" }
  end

  def test_current_profiles
    assert_equal "PASS", report["status"], report["differences"].inspect
    refute_match(/ratio|percentage/, report.keys.join(" "))
  end

  def test_allow_all_empty_ingress_is_rejected
    object("default-deny")["spec"]["ingress"] = [{}]
    assert_equal "FAIL", report["status"]
  end

  def test_world_open_ingress_is_rejected
    object("allow-ingress-to-web")["spec"]["ingress"][0]["from"] << { "ipBlock" => { "cidr" => "0.0.0.0/0" } }
    assert_equal "FAIL", report["status"]
  end

  def test_changed_allowed_field_value_is_rejected
    object("allow-ingress-to-web")["spec"]["ingress"][0]["from"][1]["ipBlock"]["cidr"] = "0.0.0.0/0"
    assert_equal "FAIL", report["status"]
  end

  def test_dns_port_is_not_allowlisted
    object("allow-dns")["spec"]["egress"][0]["ports"][0]["port"] = 80
    assert_equal "FAIL", report["status"]
  end

  def test_replica_choice_must_match
    @gke.find { |d| d["kind"] == "Deployment" }["spec"]["replicas"] = 17
    assert_equal "FAIL", report["status"]
  end

  def test_empty_collections_and_null_are_distinct
    assert_equal({ "/a" => {}, "/b" => [], "/c" => nil },
                 Portability.flatten({ "a" => {}, "b" => [], "c" => nil }))
  end

  def test_absence_is_not_a_user_string
    assert_equal({ "absent" => true }, Portability.display(Portability::ABSENT))
    refute_equal Portability.display(Portability::ABSENT), Portability.display("<absent>")
  end

  def test_paths_do_not_collide
    assert_equal 3, Portability.flatten({ "a/b" => 1, "a" => { "b" => 2 }, "a~b" => 3 }).size
  end

  def test_duplicates_raise
    @gke << @gke.first
    assert_raises(RuntimeError) { report }
  end

  def test_api_version_change_is_not_hidden
    @gke.first["apiVersion"] = "unexpected.example/v1"
    assert_equal "FAIL", report["status"]
    refute_empty report["objects_only_gke"]
  end

  def test_sequence_cannot_be_replaced_by_numeric_mapping
    policy = object("allow-dns")["spec"]
    policy["egress"] = { "0" => policy["egress"].first }
    assert_equal "FAIL", report["status"]
    assert report["differences"].any? { |d| d["cause"] == "Geaenderter YAML-Strukturtyp" }
  end

  def test_duplicate_yaml_keys_are_rejected_before_loading
    assert_raises(RuntimeError) { Portability.parse_documents("spec:\n  replicas: 2\n  replicas: 1\n") }
  end

  def test_yaml_object_tags_are_rejected
    assert_raises(Psych::DisallowedClass) { Portability.parse_documents("--- !ruby/object:Object {}\n") }
  end

  def test_yaml_aliases_are_rejected
    assert_raises(Psych::BadAlias) { Portability.parse_documents("a: &item [1]\nb: *item\n") }
  end

  def test_numeric_mapping_keys_are_rejected
    assert_raises(RuntimeError) { Portability.flatten({ "a" => { 0 => "item" } }) }
  end
end
