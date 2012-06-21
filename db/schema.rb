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
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20120621225223) do

  create_table "authentications", :force => true do |t|
    t.integer  "user_id"
    t.string   "provider"
    t.string   "uid"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "expressions", :force => true do |t|
    t.integer  "tag_id"
    t.integer  "referent_id"
    t.integer  "form"
    t.string   "locale"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "feedbacks", :force => true do |t|
    t.integer  "user_id"
    t.string   "email"
    t.string   "wherefrom"
    t.string   "doing"
    t.text     "what"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "link_refs", :force => true do |t|
    t.integer  "link_id"
    t.integer  "tag_id"
    t.integer  "owner_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "links", :force => true do |t|
    t.string   "domain"
    t.text     "uri"
    t.integer  "resource_type"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "ratings", :force => true do |t|
    t.integer  "recipe_id"
    t.integer  "scale_id"
    t.integer  "scale_val"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "user_id"
    t.integer  "rcpquery_id"
  end

  create_table "rcpqueries", :force => true do |t|
    t.integer  "session_id"
    t.integer  "user_id"
    t.integer  "owner_id"
    t.text     "tagstxt"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "listmode"
    t.integer  "status"
    t.text     "specialtags"
    t.integer  "cur_page",    :default => 1
  end

  create_table "rcprefs", :force => true do |t|
    t.integer  "recipe_id"
    t.integer  "user_id"
    t.text     "comment"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "status"
    t.integer  "privacy"
  end

  create_table "recipes", :force => true do |t|
    t.string   "title"
    t.string   "url"
    t.integer  "alias"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "picurl"
    t.text     "tagpane"
  end

  create_table "referent_relations", :force => true do |t|
    t.integer  "parent_id"
    t.integer  "child_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "referents", :force => true do |t|
    t.string   "type"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "isCountable"
    t.string   "description"
    t.integer  "tag_id"
  end

  create_table "scales", :force => true do |t|
    t.integer  "minval"
    t.integer  "maxval"
    t.string   "minlabel"
    t.string   "maxlabel"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "name"
    t.integer  "user_id"
  end

  create_table "site_referents", :force => true do |t|
    t.string   "site"
    t.string   "sample"
    t.string   "home"
    t.string   "subsite"
    t.string   "scheme"
    t.string   "host"
    t.string   "port"
    t.string   "logo"
    t.text     "tags_serialized"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "ttlcut"
    t.string   "ttlrepl"
  end

  create_table "sites", :force => true do |t|
    t.string   "site"
    t.string   "sample"
    t.string   "home"
    t.string   "subsite"
    t.string   "scheme"
    t.string   "host"
    t.string   "port"
    t.string   "name"
    t.string   "logo"
    t.text     "tags_serialized"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "ttlcut"
    t.string   "ttlrepl"
    t.integer  "referent_id"
  end

  create_table "tag_owners", :force => true do |t|
    t.integer  "tag_id"
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "tagrefs", :force => true do |t|
    t.integer  "recipe_id"
    t.integer  "tag_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "user_id"
  end

  create_table "tags", :force => true do |t|
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "tagtype"
    t.string   "normalized_name"
    t.boolean  "isGlobal"
    t.integer  "referent_id"
  end

  create_table "users", :force => true do |t|
    t.string   "username"
    t.string   "email",                  :default => "", :null => false
    t.string   "password_hash"
    t.string   "password_salt"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "encrypted_password",     :default => "", :null => false
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",          :default => 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip"
    t.string   "last_sign_in_ip"
    t.string   "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string   "unconfirmed_email"
    t.integer  "failed_attempts",        :default => 0
    t.string   "unlock_token"
    t.datetime "locked_at"
    t.integer  "role_id",                :default => 0
  end

  add_index "users", ["confirmation_token"], :name => "index_users_on_confirmation_token", :unique => true
  add_index "users", ["email"], :name => "index_users_on_email", :unique => true
  add_index "users", ["reset_password_token"], :name => "index_users_on_reset_password_token", :unique => true
  add_index "users", ["unlock_token"], :name => "index_users_on_unlock_token", :unique => true

  create_table "visitors", :force => true do |t|
    t.string   "email"
    t.string   "question"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

end
