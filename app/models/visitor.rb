# == Schema Information
#
# Table name: visitors
#
#  id         :integer         not null, primary key
#  email      :string(255)
#  question   :string(255)
#  created_at :datetime
#  updated_at :datetime
#

require 'openssl'
require 'base64'

# Implement an email checker, which really stands in for validation of both email and question:
#	If the email is valid, accept the entry
#	If both the email and question are empty, accept the entry
#	Otherwise (non-empty question or non-empty, invalid email), reject the entry
class BaremailValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    if(attribute == :baremail) 
        record.errors[:baremail] << (options[:message] || "is not an email") unless
          ( (value =~ /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i) || 
	    ((value.nil? || value.empty?) && record.question.empty?)
          )
    end
  end
end

class Visitor < ActiveRecord::Base
	attr_accessor :baremail
	attr_accessible :email, :question, :baremail

	validates :baremail,:presence=>true, 
			    :length => { :maximum => 50 },
			    :baremail => true
    before_save :encrypt_email
    @@private_key = nil
    @@public_key = nil

    def decrypt_email(password)
	return (self.baremail = self.email) if self.email.length < 50
	if(@@private_key.nil?)
	    @@private_key = OpenSSL::PKey::RSA.new(%Q{-----BEGIN RSA PRIVATE KEY-----
MIIBOgIBAAJBAL4PBQb/GTXP0oAI66zhhCTrdciHqZguhE4Iv6qMucdrOYksqGX3
QyBGTxlWIt3qJIW0rY6/rqdarbIGEeZeNWUCAwEAAQJAc571gv0bnBXyy/shTIng
9wjbHYQSU0cxK7u8xgdYWYzAEYgSvoVcvI7/D3Mn2D3U1x0ZYtJiQnloCb+Ha+Ma
IQIhANz7wZ4yqv/hJ/kjDRmsCcqorDnwqhPArniX75u3mve5AiEA3CzLJ4ppTAMD
UYxF0SzbceDfiJu+AKFdwih3mrPrKQ0CIQCVJFilc17TeVtoGs7xn5mwLCyoohO3
ZxiZjTmKp90wCQIgTn4ZnusVRuf8EuJzMXNQeHS2vDjpr8fXaRSMLzbdKzECIAFs
wWgYNlguH1QiXL4YIaTBvx+LuxpIMbQf8na1nQ5s
-----END RSA PRIVATE KEY-----},
						      password)
	end
	self.baremail = @@private_key.private_decrypt(Base64.decode64(self.email))
    end

    # Write all visitors in the database
public
    def DumpVisitors(password)
	dump = ""
	Visitor.find(:all) do  | rcd |
	    # Unencrypted email? copy to baremail and save to ensure encryption
	    if (rcd.email.length < 30)
	        rcd.baremail = rcd.email
		rcd.save || rcd.delete
	    end
	    dump.concat "#{rcd.id.to_s}: #{rcd.decrypt_email(password)} (#{rcd.email})\n"
	    nil # Keep scanning the records
	end
	dump
    end

  private

    def encrypt_email
      self.email = encrypt(baremail)
    end

    def encrypt(string)
	@@public_key = OpenSSL::PKey::RSA.new(%Q{-----BEGIN RSA PUBLIC KEY-----
MEgCQQC+DwUG/xk1z9KACOus4YQk63XIh6mYLoROCL+qjLnHazmJLKhl90MgRk8Z
ViLd6iSFtK2Ov66nWq2yBhHmXjVlAgMBAAE=
-----END RSA PUBLIC KEY-----}) if @@public_key.nil?
      Base64.encode64(@@public_key.public_encrypt(string))
    end
end
