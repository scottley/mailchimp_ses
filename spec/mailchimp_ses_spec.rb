require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "MailchimpSes" do
  let(:message) do
    {
      :subject => 'Welcome to our website!',
      :html => '<html>Welcome to our site.</html>',
      :text => 'Welcome to our website.',
      :from_name => 'David Balatero',
      :from_email => 'david@mediapiston.com',
      :to_email => ['dbalatero@gmail.com'],
      :to_name => ['David Balatero']
    }
  end

  before(:each) do
    # disabled in production.
    MailchimpSes.api_key = "test-us1"

    @valid_params = {
      :message => message,
      :tags => ['fun', 'message', 'unique'],
      :track_opens => true,
      :track_clicks => true
    }
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
        subject[:from_name].should == 'David Balatero'
      end

      it 'should set from_email' do
        subject[:from_email].should == 'david@mediapiston.com'
      end

      it 'should set to_email' do
        subject[:to_email][0].should == 'dbalatero@gmail.com'
      end

      it 'should set to_name' do
        subject[:to_name][0].should == 'David Balatero'
      end
    end

    subject { MailchimpSes.parse_message_options(message) }

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
          MailchimpSes.send_email(@valid_params)
        }.should raise_error(ArgumentError)
      end

      [:track_opens, :track_clicks].each do |field|
        it "should require #{field}" do
          @valid_params.delete(field)
          lambda {
            MailchimpSes.send_email(@valid_params)
          }.should raise_error(ArgumentError)
        end
      end

      [:html, :subject, :from_name, :from_email, :to_email].each do |field|
        it "should require message #{field}" do
          @valid_params[:message].delete(field)
          lambda {
            MailchimpSes.send_email(@valid_params)
          }.should raise_error(ArgumentError)
        end
      end

      [[:to_email, :to_name]].each do |pair|
        email_key = pair[0]
        name_key = pair[1]
        it "should not allow #{email_key} and #{name_key} to be different lengths" do
          @valid_params[:message][email_key] = ['fds@fds.com', 'a@b.com']
          @valid_params[:message][name_key] = ['My Friend Fds']

          lambda {
            MailchimpSes.send_email(@valid_params)
          }.should raise_error(ArgumentError)
        end

        it "should not allow #{email_key} with an empty #{name_key}" do
          @valid_params[:message][email_key] = ['fdsa@fdsa.com']
          @valid_params[:message][name_key] = []

          lambda {
            MailchimpSes.send_email(@valid_params)
          }.should raise_error(ArgumentError)
        end
      end
    end

    describe "real requests" do
      use_vcr_cassette 'send_email', :record => :new_episodes

      it "should return a success or failure" do
        result = MailchimpSes.send_email(@valid_params)
        result['status'].should == 'sent'
        result['message_id'].should_not be_nil
      end
    end
  end
end
