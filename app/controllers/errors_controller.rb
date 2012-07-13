class ErrorsController < ApplicationController
    ERRORS = [ 
      :internal_server_error,
      :not_found,
      :unprocessable_entity
    ].freeze

    ERRORS.each do |e|
      define_method e do
        respond_to do |format|
          format.html { render e, :layout => 'errorpage', :status => e }
          format.any { head e }
        end
      end
    end
end
