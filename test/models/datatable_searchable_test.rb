# frozen_string_literal: true

require "test_helper"

class DatatableSearchableTest < ActiveSupport::TestCase
  test "allowed sorting still orders the configured column" do
    params = { order: { "0" => { column: "0", dir: "desc" } } }
    result = User.send(:apply_sorting, User.all, params).pluck(:full_name)
    assert_equal User.pluck(:full_name).sort.reverse, result
  end

  test "untrusted direction and invalid column fall back to a safe order" do
    [ { column: "0", dir: "desc; SELECT pg_sleep(10)--" },
      { column: "-1", dir: "asc" }, { column: "999", dir: "asc" } ].each do |order|
      query = User.send(:apply_sorting, User.all, { order: { "0" => order } })
      assert_equal User.order(created_at: :desc).to_sql, query.to_sql
      assert_equal User.count, query.count
    end
  end
end
