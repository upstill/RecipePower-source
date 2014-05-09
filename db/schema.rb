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

ActiveRecord::Schema.define(version: 20140508005728) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "authentications", force: true do |t|
    t.integer  "user_id"
    t.string   "provider"
    t.string   "uid"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "channels_referents", id: false, force: true do |t|
    t.integer "channel_id"
    t.integer "referent_id"
  end

  create_table "delayed_jobs", force: true do |t|
    t.integer  "priority",   default: 0
    t.integer  "attempts",   default: 0
    t.text     "handler"
    t.text     "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string   "locked_by"
    t.string   "queue"
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  add_index "delayed_jobs", ["priority", "run_at"], name: "delayed_jobs_priority", using: :btree

  create_table "expressions", force: true do |t|
    t.integer  "tag_id"
    t.integer  "referent_id"
    t.integer  "form"
    t.string   "locale"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "feed_entries", force: true do |t|
    t.string   "name"
    t.text     "summary"
    t.text     "url"
    t.datetime "published_at"
    t.text     "guid"
    t.datetime "created_at",   null: false
    t.datetime "updated_at",   null: false
    t.integer  "feed_id"
    t.integer  "recipe_id"
  end

  create_table "feedbacks", force: true do |t|
    t.integer  "user_id"
    t.string   "email"
    t.string   "page"
    t.string   "doing"
    t.text     "comment"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "subject"
    t.boolean  "docontact"
  end

  create_table "feeds", force: true do |t|
    t.text     "url"
    t.integer  "feedtype",    default: 0
    t.string   "description"
    t.integer  "site_id"
    t.boolean  "approved"
    t.datetime "created_at",              null: false
    t.datetime "updated_at",              null: false
    t.string   "title"
  end

  create_table "feeds_users", force: true do |t|
    t.integer "feed_id"
    t.integer "user_id"
  end

  create_table "finders", force: true do |t|
    t.string   "finds"
    t.string   "selector"
    t.string   "read_attrib"
    t.integer  "site_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "notifications", force: true do |t|
    t.integer  "source_id"
    t.integer  "target_id"
    t.integer  "notification_type"
    t.string   "notification_token"
    t.text     "info"
    t.datetime "created_at",                        null: false
    t.datetime "updated_at",                        null: false
    t.boolean  "accepted",           default: true
  end

  create_table "private_subscriptions", force: true do |t|
    t.integer  "user_id"
    t.integer  "tag_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "priority",   default: 10
  end

  create_table "products", force: true do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "ratings", force: true do |t|
    t.integer  "recipe_id"
    t.integer  "scale_id"
    t.integer  "scale_val"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "user_id"
    t.integer  "rcpquery_id"
  end

  create_table "rcpqueries", force: true do |t|
    t.integer  "session_id"
    t.integer  "user_id"
    t.integer  "owner_id"
    t.text     "tagstxt"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "listmode"
    t.integer  "status"
    t.text     "specialtags"
    t.integer  "cur_page",    default: 1
    t.integer  "friend_id",   default: 0
    t.integer  "channel_id",  default: 0
    t.string   "which_list",  default: "mine"
  end

  create_table "rcprefs", force: true do |t|
    t.integer  "recipe_id"
    t.integer  "user_id"
    t.text     "comment"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "status",        default: 8
    t.boolean  "private",       default: false
    t.boolean  "in_collection", default: true
    t.integer  "edit_count",    default: 0
  end

  create_table "recipes", force: true do |t|
    t.string   "title"
    t.string   "url"
    t.integer  "alias"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "picurl"
    t.text     "tagpane"
    t.integer  "thumbnail_id"
    t.text     "href"
    t.text     "description"
    t.integer  "picture_id"
  end

  create_table "references", force: true do |t|
    t.datetime "created_at",                           null: false
    t.datetime "updated_at",                           null: false
    t.integer  "reference_type"
    t.text     "url"
    t.integer  "affiliate_id"
    t.string   "type",           default: "Reference"
    t.text     "thumbdata"
    t.integer  "status"
    t.boolean  "canonical",      default: false
  end

  create_table "referent_relations", force: true do |t|
    t.integer  "parent_id"
    t.integer  "child_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "referents", force: true do |t|
    t.string   "type"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "isCountable"
    t.string   "description"
    t.integer  "tag_id"
  end

  create_table "referments", force: true do |t|
    t.integer  "referent_id"
    t.integer  "referee_id"
    t.string   "referee_type"
    t.datetime "created_at",   null: false
    t.datetime "updated_at",   null: false
  end

  create_table "rp_events", force: true do |t|
    t.integer  "verb"
    t.integer  "source_id"
    t.string   "subject_type"
    t.integer  "subject_id"
    t.string   "target_type"
    t.integer  "target_id"
    t.text     "data"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "scales", force: true do |t|
    t.integer  "minval"
    t.integer  "maxval"
    t.string   "minlabel"
    t.string   "maxlabel"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "name"
    t.integer  "user_id"
  end

  create_table "sites", force: true do |t|
    t.string   "oldsite"
    t.text     "sample"
    t.string   "home"   # Very optional location of the site's home page, which may redirect to subsite
    t.string   "subsite"
    t.string   "scheme"
    t.string   "host"
    t.string   "port"
    t.string   "oldname"
    t.string   "logo"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "ttlcut"
    t.integer  "referent_id"
    t.boolean  "reviewed",     default: false
    t.text     "description"
    t.integer  "thumbnail_id"
  end

  create_table "tag_owners", force: true do |t|
    t.integer  "tag_id"
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "taggings", force: true do |t|
    t.integer  "user_id"
    t.integer  "tag_id"
    t.integer  "entity_id"
    t.string   "entity_type"
    t.boolean  "is_definition", default: false
    t.datetime "created_at",                    null: false
    t.datetime "updated_at",                    null: false
  end

  add_index "taggings", ["user_id", "tag_id", "entity_id", "entity_type", "is_definition"], name: "tagging_unique", unique: true, using: :btree

  create_table "tags", force: true do |t|
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "tagtype"
    t.string   "normalized_name"
    t.boolean  "isGlobal"
    t.integer  "referent_id"
  end

  add_index "tags", ["name", "tagtype"], name: "tag_name_type_unique", unique: true, using: :btree
  add_index "tags", ["normalized_name"], name: "tag_normalized_name_index", using: :btree

  create_table "thumbnails", force: true do |t|
    t.text     "url"
    t.text     "thumbdata"
    t.integer  "status"
    t.string   "status_text"
    t.integer  "thumbsize",   default: 200
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
  end

  add_index "thumbnails", ["url"], name: "index_thumbnails_on_url", unique: true, using: :btree

  create_table "user_relations", force: true do |t|
    t.integer  "follower_id"
    t.integer  "followee_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "users", force: true do |t|
    t.string   "username"
    t.string   "email",                             default: "",    null: false
    t.string   "password_hash"
    t.string   "password_salt"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "encrypted_password",                default: ""
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",                     default: 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip"
    t.string   "last_sign_in_ip"
    t.string   "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string   "unconfirmed_email"
    t.integer  "failed_attempts",                   default: 0
    t.string   "unlock_token"
    t.datetime "locked_at"
    t.integer  "role_id",                           default: 2
    t.string   "fullname",                          default: ""
    t.string   "image",                             default: ""
    t.text     "about",                             default: ""
    t.string   "invitation_token",       limit: 66
    t.datetime "invitation_sent_at"
    t.datetime "invitation_accepted_at"
    t.integer  "invitation_limit"
    t.integer  "invited_by_id"
    t.string   "invited_by_type"
    t.text     "invitation_message"
    t.integer  "channel_referent_id",               default: 0
    t.text     "browser_serialized"
    t.boolean  "private",                           default: false
    t.string   "invitation_issuer"
    t.datetime "invitation_created_at"
    t.string   "first_name"
    t.string   "last_name"
    t.integer  "thumbnail_id"
  end

  add_index "users", ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true, using: :btree
  add_index "users", ["email"], name: "index_users_on_email", unique: true, using: :btree
  add_index "users", ["invitation_token"], name: "index_users_on_invitation_token", using: :btree
  add_index "users", ["invited_by_id"], name: "index_users_on_invited_by_id", using: :btree
  add_index "users", ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true, using: :btree
  add_index "users", ["unlock_token"], name: "index_users_on_unlock_token", unique: true, using: :btree

  create_table "visitors", force: true do |t|
    t.string   "email"
    t.string   "question"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "votes", force: true do |t|
    t.integer  "user_id"
    t.string   "entity_type"
    t.integer  "entity_id"
    t.string   "original_entity_type"
    t.integer  "original_entity_id"
    t.boolean  "up"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

end
