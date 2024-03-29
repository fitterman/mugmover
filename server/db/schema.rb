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

ActiveRecord::Schema.define(version: 20150611171455) do

  create_table "faces", force: true do |t|
    t.integer  "photo_id"
    t.string   "face_uuid"
    t.float    "x"
    t.float    "y"
    t.float    "width"
    t.float    "height"
    t.integer  "named_face_id"
    t.boolean  "visible"
    t.integer  "face_key"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "manual"
    t.datetime "deleted_at"
    t.text     "thumbnail"
    t.float    "thumbscale"
  end

  add_index "faces", ["deleted_at"], name: "index_faces_on_deleted_at"

  create_table "hosting_service_accounts", force: true do |t|
    t.string   "name"
    t.string   "handle"
    t.string   "auth_token"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "named_faces", force: true do |t|
    t.integer  "hosting_service_account_id"
    t.string   "database_uuid"
    t.string   "face_name_uuid"
    t.integer  "face_key"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "public_name"
    t.string   "private_name"
    t.text     "note"
    t.integer  "face_icon_id"
  end

  create_table "photos", force: true do |t|
    t.integer  "service_collection_id"
    t.string   "database_uuid"
    t.string   "master_uuid"
    t.integer  "version_uuid"
    t.integer  "width"
    t.integer  "height"
    t.string   "name"
    t.string   "filename"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "hosting_service_account_id"
    t.string   "hosting_service_photo_id"
    t.string   "original_date"
    t.text     "request"
    t.datetime "date_uploaded"
    t.string   "original_format"
    t.integer  "flag"
    t.text     "thumbnail"
    t.string   "web_url"
    t.string   "original_url"
    t.string   "large_url"
  end

  create_table "service_collections", force: true do |t|
    t.string   "name"
    t.integer  "hosting_service_account_id"
    t.string   "hosting_service_folder_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "users", force: true do |t|
    t.string   "email",                  default: "", null: false
    t.string   "encrypted_password",     default: "", null: false
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",          default: 0,  null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip"
    t.string   "last_sign_in_ip"
    t.datetime "created_at",                          null: false
    t.datetime "updated_at",                          null: false
  end

  add_index "users", ["email"], name: "index_users_on_email", unique: true
  add_index "users", ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true

end
