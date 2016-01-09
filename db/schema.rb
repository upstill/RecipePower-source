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

ActiveRecord::Schema.define(version: 20160108021256) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "answers", force: :cascade do |t|
    t.string   "answer",      default: ""
    t.integer  "user_id"
    t.integer  "question_id"
    t.datetime "created_at",               null: false
    t.datetime "updated_at",               null: false
  end

  add_index "answers", ["user_id"], name: "index_answers_on_user_id", using: :btree

  create_table "authentications", force: :cascade do |t|
    t.integer  "user_id"
    t.string   "provider",   limit: 255
    t.string   "uid",        limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "channels_referents", id: false, force: :cascade do |t|
    t.integer "channel_id"
    t.integer "referent_id"
  end

  create_table "deferred_requests", id: false, force: :cascade do |t|
    t.string   "session_id",                      null: false
    t.text     "requests",   default: "--- []\n"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "deferred_requests", ["session_id"], name: "index_deferred_requests", unique: true, using: :btree

  create_table "delayed_jobs", force: :cascade do |t|
    t.integer  "priority",               default: 0
    t.integer  "attempts",               default: 0
    t.text     "handler"
    t.text     "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string   "locked_by",  limit: 255
    t.string   "queue",      limit: 255
    t.datetime "created_at",                         null: false
    t.datetime "updated_at",                         null: false
  end

  add_index "delayed_jobs", ["priority", "run_at"], name: "delayed_jobs_priority", using: :btree

  create_table "event_notices", force: :cascade do |t|
    t.integer  "event_id"
    t.integer  "user_id"
    t.boolean  "read",       default: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "expressions", force: :cascade do |t|
    t.integer  "tag_id"
    t.integer  "referent_id"
    t.integer  "form"
    t.string   "locale",      limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "feed_entries", force: :cascade do |t|
    t.string   "title",        limit: 255
    t.text     "summary"
    t.text     "url"
    t.datetime "published_at"
    t.text     "guid"
    t.datetime "created_at",               null: false
    t.datetime "updated_at",               null: false
    t.integer  "feed_id"
    t.integer  "recipe_id"
    t.integer  "picture_id"
  end

  create_table "feedbacks", force: :cascade do |t|
    t.integer  "user_id"
    t.string   "email",      limit: 255
    t.string   "page",       limit: 255
    t.string   "doing",      limit: 255
    t.text     "comment"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "subject",    limit: 255
    t.boolean  "docontact"
  end

  create_table "feeds", force: :cascade do |t|
    t.text     "url"
    t.integer  "feedtype",                       default: 0
    t.string   "description",        limit: 255
    t.integer  "site_id"
    t.boolean  "approved"
    t.datetime "created_at",                                       null: false
    t.datetime "updated_at",                                       null: false
    t.string   "title",              limit: 255
    t.string   "status",                         default: "ready"
    t.integer  "picture_id"
    t.datetime "last_post_date"
    t.integer  "feed_entries_count",             default: 0
  end

  create_table "finders", force: :cascade do |t|
    t.string   "finds",       limit: 255
    t.string   "selector",    limit: 255
    t.string   "read_attrib", limit: 255
    t.integer  "site_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "lists", force: :cascade do |t|
    t.integer  "owner_id"
    t.integer  "name_tag_id"
    t.integer  "availability", default: 0
    t.text     "ordering",     default: ""
    t.text     "description",  default: ""
    t.text     "notes",        default: ""
    t.boolean  "pullin",       default: true
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "picture_id"
  end

  create_table "lists_tags", force: :cascade do |t|
    t.integer  "tag_id"
    t.integer  "list_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "notifications", force: :cascade do |t|
    t.integer  "source_id"
    t.integer  "target_id"
    t.integer  "notification_type"
    t.string   "notification_token", limit: 255
    t.text     "info"
    t.datetime "created_at",                                     null: false
    t.datetime "updated_at",                                     null: false
    t.boolean  "accepted",                       default: true
    t.string   "shared_type"
    t.integer  "shared_id"
    t.boolean  "autosave",                       default: false
  end

  create_table "private_subscriptions", force: :cascade do |t|
    t.integer  "user_id"
    t.integer  "tag_id"
    t.integer  "priority",   default: 10
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "products", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer  "picture_id"
  end

  create_table "ratings", force: :cascade do |t|
    t.integer  "recipe_id"
    t.integer  "scale_id"
    t.integer  "scale_val"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "user_id"
    t.integer  "rcpquery_id"
  end

  create_table "rcpqueries", force: :cascade do |t|
    t.integer  "session_id"
    t.integer  "user_id"
    t.integer  "owner_id"
    t.text     "tagstxt"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "listmode",    limit: 255
    t.integer  "status"
    t.text     "specialtags"
    t.integer  "cur_page",                default: 1
    t.integer  "friend_id",               default: 0
    t.integer  "channel_id",              default: 0
    t.string   "which_list",  limit: 255, default: "mine"
  end

  create_table "rcprefs", force: :cascade do |t|
    t.integer  "entity_id"
    t.integer  "user_id"
    t.text     "comment",       default: ""
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "private",       default: false
    t.boolean  "in_collection", default: false
    t.integer  "edit_count",    default: 0
    t.string   "entity_type",   default: "Recipe"
    t.integer  "rating"
  end

  create_table "recipes", force: :cascade do |t|
    t.string   "title",       limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "description"
    t.integer  "picture_id"
  end

  add_index "recipes", ["id"], name: "recipes_index_by_id", unique: true, using: :btree
  add_index "recipes", ["title"], name: "recipes_index_by_title", using: :btree

  create_table "references", force: :cascade do |t|
    t.datetime "created_at",                                    null: false
    t.datetime "updated_at",                                    null: false
    t.text     "url"
    t.integer  "affiliate_id"
    t.string   "type",         limit: 25, default: "Reference"
    t.text     "thumbdata"
    t.integer  "status"
    t.boolean  "canonical",               default: false
    t.string   "host"
  end

  add_index "references", ["affiliate_id", "type"], name: "references_index_by_affil_and_type", using: :btree
  add_index "references", ["id"], name: "references_index_by_id", unique: true, using: :btree
  add_index "references", ["url", "type"], name: "references_index_by_url_and_type", unique: true, using: :btree

  create_table "referent_relations", force: :cascade do |t|
    t.integer  "parent_id"
    t.integer  "child_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "referents", force: :cascade do |t|
    t.string   "type",        limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "isCountable"
    t.string   "description", limit: 255
    t.integer  "tag_id"
  end

  create_table "referments", force: :cascade do |t|
    t.integer  "referent_id"
    t.integer  "referee_id"
    t.string   "referee_type", limit: 255
    t.datetime "created_at",               null: false
    t.datetime "updated_at",               null: false
  end

  create_table "results_caches", id: false, force: :cascade do |t|
    t.string   "session_id",                          null: false
    t.text     "params",         default: "--- {}\n"
    t.text     "cache"
    t.string   "type",                                null: false
    t.string   "result_typestr", default: "",         null: false
    t.text     "partition"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "results_caches", ["session_id", "type", "result_typestr"], name: "index_results_caches_on_session_id_and_type_and_result_typestr", unique: true, using: :btree

  create_table "rp_events", force: :cascade do |t|
    t.integer  "verb"
    t.integer  "subject_id"
    t.string   "direct_object_type",   limit: 255
    t.integer  "direct_object_id"
    t.string   "indirect_object_type", limit: 255
    t.integer  "indirect_object_id"
    t.text     "data"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "subject_type",                     default: "User"
  end

  create_table "scales", force: :cascade do |t|
    t.integer  "minval"
    t.integer  "maxval"
    t.string   "minlabel",   limit: 255
    t.string   "maxlabel",   limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "name",       limit: 255
    t.integer  "user_id"
  end

  create_table "sites", force: :cascade do |t|
    t.text     "sample"
    t.string   "oldname",              limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "ttlcut",               limit: 255
    t.integer  "referent_id"
    t.boolean  "reviewed",                         default: false
    t.text     "description"
    t.integer  "thumbnail_id"
    t.integer  "feeds_count",                      default: 0
    t.integer  "approved_feeds_count",             default: 0
  end

  add_index "sites", ["id"], name: "sites_index_by_id", unique: true, using: :btree

  create_table "suggestions", force: :cascade do |t|
    t.string   "base_type"
    t.integer  "base_id"
    t.integer  "viewer_id"
    t.string   "session"
    t.text     "filter"
    t.integer  "results_cache_id"
    t.text     "results"
    t.string   "type"
    t.boolean  "pending",          default: false
    t.boolean  "ready",            default: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "tag_owners", force: :cascade do |t|
    t.integer  "tag_id"
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "tag_selections", force: :cascade do |t|
    t.integer  "tagset_id"
    t.integer  "user_id"
    t.integer  "tag_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "tag_selections", ["tag_id"], name: "index_tag_selections_on_tag_id", using: :btree
  add_index "tag_selections", ["tagset_id"], name: "index_tag_selections_on_tagset_id", using: :btree
  add_index "tag_selections", ["user_id"], name: "index_tag_selections_on_user_id", using: :btree

  create_table "taggings", force: :cascade do |t|
    t.integer  "user_id"
    t.integer  "tag_id"
    t.integer  "entity_id"
    t.string   "entity_type", limit: 255
    t.datetime "created_at",              null: false
    t.datetime "updated_at",              null: false
  end

  create_table "tags", force: :cascade do |t|
    t.string   "name",            limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "tagtype"
    t.string   "normalized_name", limit: 255
    t.boolean  "isGlobal"
    t.integer  "referent_id"
  end

  add_index "tags", ["id"], name: "tags_index_by_id", unique: true, using: :btree
  add_index "tags", ["name", "tagtype"], name: "tag_name_type_unique", unique: true, using: :btree
  add_index "tags", ["normalized_name"], name: "tag_normalized_name_index", using: :btree

  create_table "tags_caches", id: false, force: :cascade do |t|
    t.string "session_id"
    t.text   "tags",       default: "--- {}\n"
  end

  add_index "tags_caches", ["session_id"], name: "index_tags_caches_on_session_id", using: :btree

  create_table "tagsets", force: :cascade do |t|
    t.string   "title"
    t.integer  "tagtype"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "user_relations", force: :cascade do |t|
    t.integer  "follower_id"
    t.integer  "followee_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "users", force: :cascade do |t|
    t.string   "username",               limit: 255
    t.string   "email",                  limit: 255, default: "",    null: false
    t.string   "password_hash",          limit: 255
    t.string   "password_salt",          limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "encrypted_password",     limit: 255, default: ""
    t.string   "reset_password_token",   limit: 255
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",                      default: 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip",     limit: 255
    t.string   "last_sign_in_ip",        limit: 255
    t.string   "confirmation_token",     limit: 255
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string   "unconfirmed_email",      limit: 255
    t.integer  "failed_attempts",                    default: 0
    t.string   "unlock_token",           limit: 255
    t.datetime "locked_at"
    t.integer  "role_id",                            default: 2
    t.string   "fullname",               limit: 255, default: ""
    t.text     "about",                              default: ""
    t.string   "invitation_token",       limit: 66
    t.datetime "invitation_sent_at"
    t.datetime "invitation_accepted_at"
    t.integer  "invitation_limit"
    t.integer  "invited_by_id"
    t.string   "invited_by_type",        limit: 255
    t.text     "invitation_message"
    t.integer  "channel_referent_id",                default: 0
    t.text     "browser_serialized"
    t.boolean  "private",                            default: false
    t.string   "invitation_issuer",      limit: 255
    t.datetime "invitation_created_at"
    t.string   "first_name",             limit: 255
    t.string   "last_name",              limit: 255
    t.integer  "thumbnail_id"
    t.integer  "count_of_collecteds",                default: 0,     null: false
    t.integer  "alias_id"
  end

  add_index "users", ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true, using: :btree
  add_index "users", ["email"], name: "index_users_on_email", unique: true, using: :btree
  add_index "users", ["invitation_token"], name: "index_users_on_invitation_token", using: :btree
  add_index "users", ["invited_by_id"], name: "index_users_on_invited_by_id", using: :btree
  add_index "users", ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true, using: :btree
  add_index "users", ["unlock_token"], name: "index_users_on_unlock_token", unique: true, using: :btree

  create_table "visitors", force: :cascade do |t|
    t.string   "email",      limit: 255
    t.string   "question",   limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "votes", id: false, force: :cascade do |t|
    t.integer  "user_id"
    t.string   "entity_type"
    t.integer  "entity_id"
    t.boolean  "up"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "votes", ["user_id", "entity_type", "entity_id"], name: "index_votes_on_user_id_and_entity_type_and_entity_id", unique: true, using: :btree

  add_foreign_key "answers", "users"
  add_foreign_key "tag_selections", "tags"
  add_foreign_key "tag_selections", "tagsets"
  add_foreign_key "tag_selections", "users"
end
