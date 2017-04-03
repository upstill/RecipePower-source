# This is a manifest file that'll be compiled into including all the files listed below.
# Add new JavaScript/Coffee code in separate files in this directory and they'll automatically
# be included in the compiled file accessible from http://example.com/assets/application.js
# It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
# the compiled file.
#
# Place your application-specific JavaScript functions and classes here
# This file is automatically included by javascript_include_tag :defaults

#= require jquery-migrate
#= require jquery_ujs
#= require jquery.ui.widget
#= require_self
#= require arch/collection.js.coffee
#= require_directory ../../../vendor/assets/javascripts/jquery_addons
#= require JavaScript-Load-Image/load-image.all.min.js
#= require JavaScript-Canvas-to-Blob/canvas-to-blob.min.js

# NB: This ordering is significant for some reason
#= require jquery_addons/fileupload/jquery.iframe-transport.js
#= require jquery_addons/fileupload/jquery.fileupload.js
#= require jquery_addons/fileupload/jquery.fileupload-process.js
#= require jquery_addons/fileupload/jquery.fileupload-image.js

#= require imagesloaded.pkgd.min
#= require bootstrap-filestyle
#= require svg4everybody.min.js
#= require eventsource.js
#= require bootbox
#= require history
#= require masonry4.pkgd

#= require authentication
#= require messaging

# require_directory ./controllers
# require bm
# require errors
# require expressions
# require invitations
# require referents
# require registrations
# require sites

#= require_directory ./common
#= require_directory ./views
#= require_directory ./concerns
# require views/edit_recipe
# require views/pic_picker
# require views/rcp_list

# require injector
# require microformat
# require oldRP
# require rails
# require RPDialogTest
# require RPfields
# require RPquery

window.RP ||= {}
