require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "MailchimpSes" do
  let(:message) do
    {
      :subject => 'Welcome to our website!',
      :html => '<html>Welcome to our site.</html>',
      :text => 'Welcome to our website.',
      :from_name => 'Mr. Tester',
      :from_email => 'mrtester@testaland.com',
      :to_email => ['msreceiver@gmail.com'],
      :to_name => ['Ms. Receiver']
    }
  end

  let(:options) do
    {
      :message => message,
      :tags => ['fun', 'message', 'unique'],
      :track_opens => true,
      :track_clicks => true
    }
  end

  before(:each) do
    # disabled in production.
    MailchimpSes.api_key = "test-us2"
  end

  describe "#parse_options" do
    subject { MailchimpSes.parse_options(options) }

    it "should set autogen_html to true by default" do
      subject[:autogen_html].should == 'true'
    end

    it "should allow overriding autogen_html to false" do
      options[:autogen_html] = false
      subject[:autogen_html].should == 'false'
    end
  end

  describe "#parse_message_options" do
    shared_examples_for 'basic message parser' do
      it 'should set subject' do
        subject[:subject].should == 'Welcome to our website!'
      end

      it 'should set html' do
        subject[:html].should == '<html>Welcome to our site.</html>'
      end

      it 'should set text' do
        subject[:text].should == 'Welcome to our website.'
      end

      it 'should set from_name' do
        subject[:from_name].should == 'Mr. Tester'
      end

      it 'should set from_email' do
        subject[:from_email].should == 'mrtester@testaland.com'
      end

      it 'should set to_email' do
        subject[:to_email][0].should == 'msreceiver@gmail.com'
      end

      it 'should set to_name' do
        subject[:to_name][0].should == 'Ms. Receiver'
      end
    end

    subject { MailchimpSes.parse_message_options(message) }

    describe "with reply_to option" do
      it "should set reply_to from an array" do
        message.merge!(:reply_to => ['dude@dude.com'])
        subject[:reply_to][0].should == 'dude@dude.com'
      end
      
      it "should ignore reply_to if set to nil" do
        message.merge!(:reply_to => nil)
        subject[:reply_to].should == nil
      end
      
      it_should_behave_like 'basic message parser'
    end

    describe "with cc options" do
      before do
        message.merge!(:cc_email => ['myfriend@gmail.com'],
                       :cc_name  => ['My Friend'])
      end

      it "should set cc_email" do
        subject[:cc_email][0].should == 'myfriend@gmail.com'
      end

      it 'should set cc_name' do
        subject[:cc_name][0].should == 'My Friend'
      end

      it 'should raise an error if the names do not match emails' do
        message[:cc_name] = ['One', 'Two']
        lambda {
          subject[:cc_name]
        }.should raise_error(ArgumentError)
      end

      it_should_behave_like 'basic message parser'
    end

    describe "with bcc options" do
      before do
        message.merge!(:bcc_email => ['bccguy@gmail.com'],
                       :bcc_name => ['BCC Guy'])
      end

      it "should set bcc_email" do
        subject[:bcc_email][0].should == 'bccguy@gmail.com'
      end

      it 'should set cc_name' do
        subject[:bcc_name][0].should == 'BCC Guy'
      end

      it 'should raise an error if the names do not match emails' do
        message[:bcc_name] = ['One', 'Two']
        lambda {
          subject[:bcc_name]
        }.should raise_error(ArgumentError)
      end

      it_should_behave_like 'basic message parser'

    end
  end

  describe "#send_email" do
    describe "error checking" do
      it "should raise error w/ no api key" do
        MailchimpSes.api_key = nil
        lambda {
          MailchimpSes.send_email(options)
        }.should raise_error(ArgumentError)
      end

      [:track_opens, :track_clicks].each do |field|
        it "should require #{field}" do
          options.delete(field)
          lambda {
            MailchimpSes.send_email(options)
          }.should raise_error(ArgumentError)
        end
      end

      [:html, :subject, :from_name, :from_email, :to_email].each do |field|
        it "should require message #{field}" do
          options[:message].delete(field)
          lambda {
            MailchimpSes.send_email(options)
          }.should raise_error(ArgumentError)
        end
      end

      [[:to_email, :to_name]].each do |pair|
        email_key = pair[0]
        name_key = pair[1]
        it "should not allow #{email_key} and #{name_key} to be different lengths" do
          options[:message][email_key] = ['fds@fds.com', 'a@b.com']
          options[:message][name_key] = ['My Friend Fds']

          lambda {
            MailchimpSes.send_email(options)
          }.should raise_error(ArgumentError)
        end

        it "should not allow #{email_key} with an empty #{name_key}" do
          options[:message][email_key] = ['fdsa@fdsa.com']
          options[:message][name_key] = []

          lambda {
            MailchimpSes.send_email(options)
          }.should raise_error(ArgumentError)
        end
      end
    end

    describe "real requests" do
      use_vcr_cassette 'send_email', :record => :new_episodes

      it "should return a success or failure" do
        result = MailchimpSes.send_email(options)
        result['status'].should == 'sent'
        result['message_id'].should_not be_nil
      end
    end
  end
end
