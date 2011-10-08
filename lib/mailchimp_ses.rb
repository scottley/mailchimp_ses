require 'json'
require 'pry'
require 'rest-client'

class MailchimpSes
  @api_key = nil

  class << self
    attr_accessor :api_key
  end

  def self.verify_email_address(email)
    check_api_key!
    uri = "http://#{datacenter}.sts.mailchimp.com/1.0/VerifyEmailAddress"
    req_opts = {:email => email, :apikey => MailchimpSes.api_key}
    response = RestClient.post(uri, req_opts)
    response.code==200 ? true : false
  end
  
  def self.send_email(options)
    check_api_key!
    uri = "http://#{datacenter}.sts.mailchimp.com/1.0/SendEmail"
    req_opts = parse_options(options).merge({:apikey => MailchimpSes.api_key})
    response = RestClient.post(uri, req_opts, {:accept => :json})
    JSON.parse(response.body)
  end

  DEFAULT_OPTIONS = { :autogen_html => true }
  def self.parse_options(options)
    options = DEFAULT_OPTIONS.merge(options)

    # Handle tags.
    tags = nil
    if options[:tags] && options[:tags].size > 0
      tags = convert_to_hash_array(options[:tags])
    end

    {
      :message => parse_message_options(options[:message]),
      :track_opens => extract_param(options, :track_opens).to_s,
      :track_clicks => extract_param(options, :track_clicks).to_s,
      :autogen_html => extract_param(options, :autogen_html).to_s,
      :tags => tags
    }
  end

  OPTIONAL_MESSAGE_FIELDS = [:to_name, :reply_to, :cc_email, :cc_name, :bcc_email, :bcc_name]
  def self.parse_message_options(message_options)
    message = {
      :html => extract_param(message_options, :html),
      :text => message_options[:text],
      :subject => extract_param(message_options, :subject),
      :from_name => extract_param(message_options, :from_name),
      :from_email => extract_param(message_options, :from_email),
      :to_email => convert_to_hash_array(extract_param(message_options, :to_email))
    }

    OPTIONAL_MESSAGE_FIELDS.each do |field|
      set_optional_field!(message, message_options, field)
    end

    # Check lengths of arrays.
    check_recipients!(message, :to_email, :to_name)
    check_recipients!(message, :cc_email, :cc_name)
    check_recipients!(message, :bcc_email, :bcc_name)

    message
  end

private

  def self.set_optional_field!(message, options, key)
    if options.has_key?(key) && !options[key].nil? && !options[key].empty?
      message[key] = convert_to_hash_array(options[key])
    end
  end

  def self.check_recipients!(message, email_key, name_key)
    if message.has_key?(email_key) || message.has_key?(name_key)
      emails = message[email_key].size rescue 0
      names = message[name_key].size rescue 0

      if emails != names
        raise ArgumentError, "#{email_key} and #{name_key} need the same number of values"
      end
    end
  end

  def self.check_api_key!
    if self.api_key.nil?
      raise ArgumentError, "Set MailchimpSes.api_key in your config."
    end
  end

  def self.convert_to_hash_array(value)
    # Turn strings into 1-element arrays.
    value = value.is_a?(Array) ? value : [value]

    hash = {}
    value.each_with_index { |val, i| hash[i] = val }
    hash
  end

  def self.extract_param(hash, key)
    if !hash.has_key?(key) || (hash[key].respond_to?(:empty?) && hash[key].empty?)
      raise ArgumentError, "missing required #{key}"
    end
    hash[key]
  end

  def self.datacenter
    api_key.split(/-/).last
  end
end

# post(:send_email) do |options|
#   check_api_key!
# 
#   uri "http://#{datacenter}.sts.mailchimp.com/1.0/SendEmail"
#   params(parse_options(options))
# 
#   handler do |response|
#     json = JSON.parse(response.body)
#   end
# end

# post(:verify_email_address) do |email|
#   check_api_key!
#   uri "http://#{datacenter}.sts.mailchimp.com/1.0/VerifyEmailAddress"
#   params :email => email
#   handler do |response|
#     true
#   end
# end