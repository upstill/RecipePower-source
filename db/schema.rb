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

ActiveRecord::Schema.define(version: 20191114023821) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "activ_notifications", id: :serial, force: :cascade do |t|
    t.integer "target_id", null: false
    t.string "target_type", null: false
    t.integer "notifiable_id", null: false
    t.string "notifiable_type", null: false
    t.string "key", null: false
    t.integer "group_id"
    t.string "group_type"
    t.integer "group_owner_id"
    t.integer "notifier_id"
    t.string "notifier_type"
    t.text "parameters"
    t.datetime "opened_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["group_owner_id"], name: "index_activ_notifications_on_group_owner_id"
    t.index ["group_type", "group_id"], name: "index_activ_notifications_on_group_type_and_group_id"
    t.index ["notifiable_type", "notifiable_id"], name: "index_activ_notifications_on_notifiable_type_and_notifiable_id"
    t.index ["notifier_type", "notifier_id"], name: "index_activ_notifications_on_notifier_type_and_notifier_id"
    t.index ["target_type", "target_id"], name: "index_activ_notifications_on_target_type_and_target_id"
  end

  create_table "activ_subscriptions", id: :serial, force: :cascade do |t|
    t.integer "target_id", null: false
    t.string "target_type", null: false
    t.string "key", null: false
    t.boolean "subscribing", default: true, null: false
    t.boolean "subscribing_to_email", default: true, null: false
    t.datetime "subscribed_at"
    t.datetime "unsubscribed_at"
    t.datetime "subscribed_to_email_at"
    t.datetime "unsubscribed_to_email_at"
    t.text "optional_targets"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["key"], name: "index_activ_subscriptions_on_key"
    t.index ["target_type", "target_id", "key"], name: "index_activ_subscriptions_on_target_type_and_target_id_and_key", unique: true
    t.index ["target_type", "target_id"], name: "index_activ_subscriptions_on_target_type_and_target_id"
  end

  create_table "aliases", id: :serial, force: :cascade do |t|
    t.integer "page_ref_id"
    t.text "url", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["url"], name: "aliases_index_by_url", unique: true
  end

  create_table "answers", id: :serial, force: :cascade do |t|
    t.string "answer", default: ""
    t.integer "user_id"
    t.integer "question_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_answers_on_user_id"
  end

  create_table "authentications", id: :serial, force: :cascade do |t|
    t.integer "user_id"
    t.string "provider", limit: 255
    t.string "uid", limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "banned_tags", id: :serial, force: :cascade do |t|
    t.string "normalized_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["normalized_name"], name: "index_banned_tags_on_normalized_name", unique: true
  end

  create_table "channels_referents", id: false, force: :cascade do |t|
    t.integer "channel_id"
    t.integer "referent_id"
  end

  create_table "deferred_requests", id: false, force: :cascade do |t|
    t.string "session_id", null: false
    t.text "requests", default: "--- []\n"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["session_id"], name: "index_deferred_requests", unique: true
  end

  create_table "delayed_jobs", id: :serial, force: :cascade do |t|
    t.integer "priority", default: 0
    t.integer "attempts", default: 0
    t.text "handler"
    t.text "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string "locked_by", limit: 255
    t.string "queue", limit: 255
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["priority", "run_at"], name: "delayed_jobs_priority"
  end

  create_table "editions", id: :serial, force: :cascade do |t|
    t.text "opening"
    t.text "signoff"
    t.integer "recipe_id"
    t.text "recipe_before"
    t.text "recipe_after"
    t.integer "condiment_id"
    t.string "condiment_type", default: "IngredientReferent"
    t.text "condiment_before"
    t.text "condiment_after"
    t.integer "site_id"
    t.text "site_before"
    t.text "site_after"
    t.integer "list_id"
    t.text "list_before"
    t.text "list_after"
    t.integer "guest_id"
    t.string "guest_type", default: "AuthorReferent"
    t.text "guest_before"
    t.text "guest_after"
    t.boolean "published", default: false
    t.date "published_at"
    t.integer "number"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "status", default: 0
    t.integer "dj_id", default: 0
  end

  create_table "event_notices", id: :serial, force: :cascade do |t|
    t.integer "event_id"
    t.integer "user_id"
    t.boolean "read", default: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "expressions", id: :serial, force: :cascade do |t|
    t.integer "tag_id"
    t.integer "referent_id"
    t.integer "form"
    t.string "locale", limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["referent_id", "tag_id", "form", "locale"], name: "expression_unique", unique: true
  end

  create_table "feed_entries", id: :serial, force: :cascade do |t|
    t.string "title", limit: 255
    t.text "summary"
    t.text "url"
    t.datetime "published_at"
    t.text "guid"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "feed_id"
    t.integer "recipe_id"
    t.integer "picture_id"
    t.index ["feed_id", "guid"], name: "index_feed_entries_on_feed_id_and_guid"
    t.index ["feed_id", "published_at"], name: "index_feed_entries_on_feed_id_and_published_at"
  end

  create_table "feedbacks", id: :serial, force: :cascade do |t|
    t.integer "user_id"
    t.string "email", limit: 255
    t.string "page", limit: 255
    t.string "doing", limit: 255
    t.text "comment"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "subject", limit: 255
    t.boolean "docontact"
  end

  create_table "feeds", id: :serial, force: :cascade do |t|
    t.text "url"
    t.integer "feedtype", default: 0
    t.text "description"
    t.integer "site_id"
    t.boolean "approved"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "title", limit: 255
    t.string "ostatus", default: "ready"
    t.integer "picture_id"
    t.datetime "last_post_date"
    t.integer "feed_entries_count", default: 0
    t.integer "status", default: 0
    t.integer "dj_id"
    t.string "home"
    t.integer "hotness", default: 0
  end

  create_table "finders", id: :serial, force: :cascade do |t|
    t.string "label", limit: 255
    t.string "selector", limit: 255
    t.string "attribute_name", limit: 255
    t.integer "site_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "hits", default: 0
  end

  create_table "gleanings", id: :serial, force: :cascade do |t|
    t.string "entity_type"
    t.integer "entity_id"
    t.integer "status", default: 0
    t.text "results_old"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "dj_id"
    t.integer "http_status"
    t.text "err_msg"
    t.text "results"
  end

  create_table "image_references", id: :serial, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "url"
    t.text "thumbdata"
    t.integer "errcode"
    t.boolean "canonical", default: false
    t.string "host"
    t.integer "status", default: 0
    t.string "filename"
    t.string "link_text"
    t.integer "dj_id"
    t.index ["id"], name: "references_index_by_id", unique: true
    t.index ["url"], name: "image_references_index_by_url", unique: true
  end

  create_table "letsencrypt_plugin_challenges", id: :serial, force: :cascade do |t|
    t.text "response"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "list_items", id: :integer, default: nil, force: :cascade do |t|
    t.integer "user_id"
    t.integer "list_id"
    t.text "title"
    t.text "description"
    t.boolean "onHold"
    t.date "doneDate"
    t.text "link"
    t.boolean "suggested"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["list_id"], name: "index_list_items_on_list_id"
    t.index ["user_id"], name: "index_list_items_on_user_id"
  end

  create_table "list_types", id: :integer, default: nil, force: :cascade do |t|
    t.text "title"
    t.string "noun_spec"
    t.string "verb_spec"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "lists", id: :serial, force: :cascade do |t|
    t.integer "owner_id"
    t.integer "name_tag_id"
    t.integer "availability", default: 0
    t.text "ordering", default: ""
    t.text "description", default: ""
    t.text "notes", default: ""
    t.boolean "pullin", default: true
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "picture_id"
  end

  create_table "lists_tags", id: :serial, force: :cascade do |t|
    t.integer "tag_id"
    t.integer "list_id"
  end

  create_table "mercury_results", force: :cascade do |t|
    t.text "results", default: "--- {}\n"
    t.integer "http_status"
    t.text "error_message"
    t.integer "status", default: 0
    t.integer "dj_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "notifications", id: :serial, force: :cascade do |t|
    t.integer "target_id", null: false
    t.string "target_type", null: false
    t.integer "notifiable_id", null: false
    t.string "notifiable_type", null: false
    t.string "notification_token", limit: 255
    t.string "key", null: false
    t.integer "group_id"
    t.string "group_type"
    t.integer "group_owner_id"
    t.integer "notifier_id"
    t.string "notifier_type"
    t.text "parameters"
    t.datetime "opened_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["group_owner_id"], name: "index_notifications_on_group_owner_id"
    t.index ["group_type", "group_id"], name: "index_notifications_on_group_type_and_group_id"
    t.index ["notifiable_type", "notifiable_id"], name: "index_notifications_on_notifiable_type_and_notifiable_id"
    t.index ["notifier_type", "notifier_id"], name: "index_notifications_on_notifier_type_and_notifier_id"
    t.index ["target_type", "target_id"], name: "index_notifications_on_target_type_and_target_id"
  end

  create_table "oauth_access_grants", id: :integer, default: nil, force: :cascade do |t|
    t.integer "resource_owner_id", null: false
    t.integer "application_id", null: false
    t.string "token", null: false
    t.integer "expires_in", null: false
    t.text "redirect_uri", null: false
    t.datetime "created_at", null: false
    t.datetime "revoked_at"
    t.string "scopes"
    t.index ["application_id"], name: "index_oauth_access_grants_on_application_id"
    t.index ["resource_owner_id"], name: "index_oauth_access_grants_on_resource_owner_id"
    t.index ["token"], name: "index_oauth_access_grants_on_token", unique: true
  end

  create_table "oauth_access_tokens", id: :integer, default: nil, force: :cascade do |t|
    t.integer "resource_owner_id"
    t.integer "application_id"
    t.string "token", null: false
    t.string "refresh_token"
    t.integer "expires_in"
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.string "scopes"
    t.string "previous_refresh_token", default: "", null: false
    t.index ["application_id"], name: "index_oauth_access_tokens_on_application_id"
    t.index ["refresh_token"], name: "index_oauth_access_tokens_on_refresh_token", unique: true
    t.index ["resource_owner_id"], name: "index_oauth_access_tokens_on_resource_owner_id"
    t.index ["token"], name: "index_oauth_access_tokens_on_token", unique: true
  end

  create_table "oauth_applications", id: :integer, default: nil, force: :cascade do |t|
    t.string "name", null: false
    t.string "uid", null: false
    t.string "secret", null: false
    t.text "redirect_uri", null: false
    t.string "scopes", default: "", null: false
    t.boolean "confidential", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["uid"], name: "index_oauth_applications_on_uid", unique: true
  end

  create_table "offerings", id: :serial, force: :cascade do |t|
    t.integer "product_id"
    t.integer "page_ref_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "description"
    t.text "title"
  end

  create_table "page_refs", id: :serial, force: :cascade do |t|
    t.text "url"
    t.string "domain"
    t.string "link_text"
    t.integer "site_id"
    t.text "error_message"
    t.string "otype", limit: 25, default: "PageRef"
    t.text "title"
    t.datetime "date_published"
    t.string "author"
    t.integer "errcode"
    t.integer "status", default: 0
    t.integer "dj_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "http_status"
    t.integer "gleaning_id"
    t.integer "picture_id"
    t.text "description"
    t.integer "kind", default: 1
    t.integer "mercury_result_id"
    t.index ["url"], name: "page_refs_index_by_url", unique: true
  end

  create_table "private_subscriptions", id: :serial, force: :cascade do |t|
    t.integer "user_id"
    t.integer "tag_id"
    t.integer "priority", default: 10
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "products", id: :serial, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "picture_id"
    t.string "barcode"
    t.integer "bctype", default: 0
    t.string "title"
    t.integer "page_ref_id"
    t.text "description"
  end

  create_table "ratings", id: :serial, force: :cascade do |t|
    t.integer "recipe_id"
    t.integer "scale_id"
    t.integer "scale_val"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "user_id"
  end

  create_table "rcprefs", id: :serial, force: :cascade do |t|
    t.integer "entity_id"
    t.integer "user_id"
    t.text "comment", default: ""
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean "private", default: false
    t.boolean "in_collection", default: false
    t.integer "edit_count", default: 0
    t.string "entity_type", default: "Recipe"
    t.integer "rating"
    t.index ["user_id", "entity_type", "entity_id"], name: "index_rcprefs_on_user_id_and_entity_type_and_entity_id", unique: true
  end

  create_table "recipes", id: :serial, force: :cascade do |t|
    t.string "title", limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text "description"
    t.integer "picture_id"
    t.string "prep_time"
    t.string "cook_time"
    t.string "total_time"
    t.integer "prep_time_low", default: 0
    t.integer "prep_time_high", default: 0
    t.integer "cook_time_low", default: 0
    t.integer "cook_time_high", default: 0
    t.integer "total_time_low", default: 0
    t.integer "total_time_high", default: 0
    t.string "yield"
    t.integer "page_ref_id"
    t.integer "dj_id"
    t.integer "status", default: 0
    t.text "content"
    t.index ["id"], name: "recipes_index_by_id", unique: true
    t.index ["title"], name: "recipes_index_by_title"
  end

  create_table "referent_relations", id: :serial, force: :cascade do |t|
    t.integer "parent_id"
    t.integer "child_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "referents", id: :serial, force: :cascade do |t|
    t.string "type", limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean "isCountable"
    t.text "description"
    t.integer "tag_id"
    t.integer "picture_id"
  end

  create_table "referments", id: :serial, force: :cascade do |t|
    t.integer "referent_id"
    t.integer "referee_id"
    t.string "referee_type", limit: 255
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "results_caches", id: :serial, force: :cascade do |t|
    t.string "session_id", null: false
    t.text "params", default: "--- {}\n"
    t.text "cache"
    t.string "type", null: false
    t.string "result_type", default: "", null: false
    t.text "partition"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "viewer_id", null: false
    t.index ["session_id", "type", "result_type", "viewer_id"], name: "results_cache_index", unique: true
  end

  create_table "rp_events", id: :serial, force: :cascade do |t|
    t.integer "subject_id"
    t.string "direct_object_type", limit: 255
    t.integer "direct_object_id"
    t.string "indirect_object_type", limit: 255
    t.integer "indirect_object_id"
    t.text "data"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "subject_type", default: "User"
    t.string "type"
    t.integer "status", default: 0
    t.integer "dj_id"
  end

  create_table "scales", id: :serial, force: :cascade do |t|
    t.integer "minval"
    t.integer "maxval"
    t.string "minlabel", limit: 255
    t.string "maxlabel", limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "name", limit: 255
    t.integer "user_id"
  end

  create_table "scrapers", id: :serial, force: :cascade do |t|
    t.string "url"
    t.string "what"
    t.string "type", default: "Scraper"
    t.boolean "recur", default: true
    t.datetime "run_at"
    t.integer "waittime", default: 1
    t.integer "errcode", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "status", default: 0
    t.integer "dj_id"
    t.string "errmsg"
  end

  create_table "sites", id: :serial, force: :cascade do |t|
    t.text "sample"
    t.string "oldname", limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "ttlcut", limit: 255
    t.integer "referent_id"
    t.text "description"
    t.integer "thumbnail_id"
    t.integer "feeds_count", default: 0
    t.integer "approved_feeds_count", default: 0
    t.boolean "approved"
    t.integer "page_ref_id"
    t.string "root"
    t.integer "dj_id"
    t.integer "status", default: 0
    t.text "trimmers", default: "--- []\n"
    t.index ["id"], name: "sites_index_by_id", unique: true
  end

  create_table "subscriptions", id: :serial, force: :cascade do |t|
    t.integer "target_id", null: false
    t.string "target_type", null: false
    t.string "key", null: false
    t.boolean "subscribing", default: true, null: false
    t.boolean "subscribing_to_email", default: true, null: false
    t.datetime "subscribed_at"
    t.datetime "unsubscribed_at"
    t.datetime "subscribed_to_email_at"
    t.datetime "unsubscribed_to_email_at"
    t.text "optional_targets"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["key"], name: "index_subscriptions_on_key"
    t.index ["target_type", "target_id", "key"], name: "index_subscriptions_on_target_type_and_target_id_and_key", unique: true
    t.index ["target_type", "target_id"], name: "index_subscriptions_on_target_type_and_target_id"
  end

  create_table "suggestions", id: :serial, force: :cascade do |t|
    t.string "base_type"
    t.integer "base_id"
    t.integer "viewer_id"
    t.string "session"
    t.text "filter"
    t.integer "results_cache_id"
    t.text "results"
    t.string "type"
    t.boolean "pending", default: false
    t.boolean "ready", default: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "tag_owners", id: :serial, force: :cascade do |t|
    t.integer "tag_id"
    t.integer "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "tag_selections", id: :serial, force: :cascade do |t|
    t.integer "tagset_id"
    t.integer "user_id"
    t.integer "tag_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tag_id"], name: "index_tag_selections_on_tag_id"
    t.index ["tagset_id"], name: "index_tag_selections_on_tagset_id"
    t.index ["user_id"], name: "index_tag_selections_on_user_id"
  end

  create_table "taggings", id: :serial, force: :cascade do |t|
    t.integer "user_id"
    t.integer "tag_id"
    t.integer "entity_id"
    t.string "entity_type", limit: 255
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "tags", id: :serial, force: :cascade do |t|
    t.string "name", limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "tagtype"
    t.string "normalized_name", limit: 255
    t.boolean "is_global"
    t.integer "referent_id"
    t.index ["id"], name: "tags_index_by_id", unique: true
    t.index ["name", "tagtype"], name: "tag_name_type_unique", unique: true
    t.index ["normalized_name"], name: "tag_normalized_name_index"
  end

  create_table "tags_caches", id: false, force: :cascade do |t|
    t.string "session_id"
    t.text "tags", default: "--- {}\n"
    t.index ["session_id"], name: "index_tags_caches_on_session_id"
  end

  create_table "tagsets", id: :serial, force: :cascade do |t|
    t.string "title"
    t.integer "tagtype"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", id: :serial, force: :cascade do |t|
    t.string "username", limit: 255
    t.string "email", limit: 255, default: "", null: false
    t.string "password_hash", limit: 255
    t.string "password_salt", limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "encrypted_password", limit: 255, default: ""
    t.string "reset_password_token", limit: 255
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip", limit: 255
    t.string "last_sign_in_ip", limit: 255
    t.string "confirmation_token", limit: 255
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email", limit: 255
    t.integer "failed_attempts", default: 0
    t.string "unlock_token", limit: 255
    t.datetime "locked_at"
    t.integer "role_id", default: 2
    t.string "fullname", limit: 255, default: ""
    t.text "about", default: ""
    t.string "invitation_token", limit: 66
    t.datetime "invitation_sent_at"
    t.datetime "invitation_accepted_at"
    t.integer "invitation_limit"
    t.integer "invited_by_id"
    t.string "invited_by_type", limit: 255
    t.text "invitation_message"
    t.boolean "private", default: false
    t.string "invitation_issuer", limit: 255
    t.datetime "invitation_created_at"
    t.string "first_name", limit: 255
    t.string "last_name", limit: 255
    t.integer "thumbnail_id"
    t.integer "count_of_collecteds", default: 0, null: false
    t.integer "alias_id"
    t.boolean "subscribed", default: true
    t.integer "last_edition", default: 0
    t.integer "status", default: 0
    t.integer "dj_id", default: 0
    t.boolean "email_valid"
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["invitation_token"], name: "index_users_on_invitation_token"
    t.index ["invited_by_id"], name: "index_users_on_invited_by_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
  end

  create_table "visitors", id: :serial, force: :cascade do |t|
    t.string "email", limit: 255
    t.string "question", limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "votes", id: :serial, force: :cascade do |t|
    t.integer "user_id"
    t.string "entity_type"
    t.integer "entity_id"
    t.boolean "up"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "entity_type", "entity_id"], name: "index_votes_on_user_id_and_entity_type_and_entity_id", unique: true
  end

  add_foreign_key "answers", "users"
  add_foreign_key "oauth_access_grants", "oauth_applications", column: "application_id"
  add_foreign_key "oauth_access_tokens", "oauth_applications", column: "application_id"
  add_foreign_key "tag_selections", "tags"
  add_foreign_key "tag_selections", "tagsets"
  add_foreign_key "tag_selections", "users"
end
