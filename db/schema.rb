# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20140113173450) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "report_groups", force: true do |t|
    t.integer  "parent_id"
    t.text     "name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "report_groups", ["parent_id"], name: "index_report_groups_on_parent_id", using: :btree

  create_table "report_versions", force: true do |t|
    t.integer  "report_id"
    t.integer  "version"
    t.text     "data"
    t.text     "projector"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "reported",   default: false
  end

  add_index "report_versions", ["report_id", "version"], name: "index_report_versions_on_report_id_and_version", order: {"version"=>:desc}, using: :btree
  add_index "report_versions", ["report_id"], name: "index_report_versions_on_report_id", using: :btree
  add_index "report_versions", ["reported"], name: "index_report_versions_on_reported", where: "(reported = false)", using: :btree

  create_table "reports", force: true do |t|
    t.text     "name"
    t.integer  "report_group_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "reports", ["report_group_id"], name: "index_reports_on_report_group_id", using: :btree

end
