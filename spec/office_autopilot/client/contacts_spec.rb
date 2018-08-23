require 'spec_helper'

describe OfficeAutopilot::Client::Contacts do

  before do
    @contact_endpoint = "#{api_endpoint}/cdata.php"
    @client = OfficeAutopilot::Client.new(:api_id => 'xxx', :api_key => 'xxx')
    @auth_str = "Appid=#{@client.api_id}&Key=#{@client.api_key}"
  end

  def request_body(req_type, options = {})
    options = { 'reqType' => req_type }.merge(options)

    query = ''
    options.each do |key, value|
      if key == "data"
        value = escape_xml(value)
      end
      query << "#{key}=#{value}&"
    end
    query << @auth_str
  end

  describe "#xml_for_search" do
    # <search>
    #   <equation>
    #     <field>E-Mail</field>
    #     <op>e</op>
    #     <value>john@example.com</value>
    #   </equation>
    # </search>

    context "searching with one field" do
      it "returns a valid simple search data xml" do
        field = "E-Mail"
        op = "e"
        value = "john@example.com"

        xml = Nokogiri::XML(@client.send(:xml_for_search, { :field => field, :op => op, :value => value }) )
        expect(xml.at_css('field').content).to eq field
        expect(xml.at_css('op').content).to eq op
        expect(xml.at_css('value').content).to eq value
      end
    end

    context "searching with more than one field" do
      it "returns a valid multi search data xml" do
        search_options = [
          {:field => 'E-Mail', :op => 'e', :value => 'foo@example.com'},
          {:field => 'Contact Tags', :op => 'n', :value => 'bar'},
        ]

        xml = @client.send(:xml_for_search, search_options)
        xml = Nokogiri::XML(xml)
        expect(xml.css('field')[0].content).to eq 'E-Mail'
        expect(xml.css('op')[0].content).to eq 'e'
        expect(xml.css('value')[0].content).to eq 'foo@example.com'

        expect(xml.css('field')[1].content).to eq 'Contact Tags'
        expect(xml.css('op')[1].content).to eq 'n'
        expect(xml.css('value')[1].content).to eq 'bar'
      end
    end
  end

  describe "#contacts_search" do
    it "returns the matched contacts" do
      search_options = {:field => 'E-Mail', :op => 'e', :value => 'prashant@example.com'}
      search_xml = @client.send(:xml_for_search, search_options)
      contacts_xml = test_data('contacts_search_single_response.xml')

      request_body = request_body('search', 'data' => search_xml)
      stub_request(:post, @contact_endpoint).with(:body => request_body).to_return(:body => contacts_xml)

      contacts = @client.contacts_search(search_options)
      expect(WebMock).to have_requested(:post, @contact_endpoint).with(:body => request_body)
      expect(contacts).to eq @client.send(:parse_contacts_xml, contacts_xml)
    end
  end

  describe "#xml_for_contact" do
    before do
      @contact_options = {
        'Contact Information' => {'First Name' => 'Bob', 'Last Name' => 'Foo', 'E-Mail' => 'b@example.com'},
        'Lead Information' => {'Contact Owner' => 'Mr Bar'}
      }
    end

    it "returns a valid contacts xml" do
      xml = @client.send(:xml_for_contact, @contact_options)
      xml = Nokogiri::XML(xml)

      expect(xml.at_css('contact')['id']).to be_nil

      contact_info = xml.css("contact Group_Tag[name='Contact Information']")
      expect(contact_info.at_css("field[name='First Name']").content).to eq 'Bob'
      expect(contact_info.at_css("field[name='Last Name']").content).to eq 'Foo'

      lead_info = xml.css("contact Group_Tag[name='Lead Information']")
      expect(lead_info.at_css("field[name='Contact Owner']").content).to eq 'Mr Bar'
    end

    context "when 'id' is specified" do
      it "returns a valid contact xml containing the contact id" do
        @contact_options.merge!('id' => '1234')
        xml = Nokogiri::XML( @client.send(:xml_for_contact, @contact_options) )

        expect(xml.at_css('contact')['id']).to eq '1234'
        contact_info = xml.css("contact Group_Tag[name='Contact Information']")
        expect(contact_info.at_css("field[name='First Name']").content).to eq 'Bob'
        expect(contact_info.at_css("field[name='Last Name']").content).to eq 'Foo'

        lead_info = xml.css("contact Group_Tag[name='Lead Information']")
        expect(lead_info.at_css("field[name='Contact Owner']").content).to eq 'Mr Bar'
      end
    end
  end

  describe "#parse_contacts_xml" do
    context "when the results contain one contact" do
      it "returns an array containing the contact" do
        contacts = @client.send(:parse_contacts_xml, test_data('contacts_search_single_response.xml'))

        expect(contacts.size).to eq 1

        contacts.each do |contact|
          expect(contact['id']).to eq '7'
          expect(contact['Contact Information']['First Name']).to eq 'prashant'
          expect(contact['Contact Information']['Last Name']).to eq 'nadarajan'
          expect(contact['Contact Information']['E-Mail']).to eq 'prashant@example.com'
          expect(contact['Lead Information']['Contact Owner']).to eq 'Don Corleone'
        end
      end
    end

    context "when the results contain more than one contact" do
      it "returns an array containing the contacts" do
        contacts = @client.send(:parse_contacts_xml, test_data('contacts_search_multiple_response.xml'))

        expect(contacts.size).to eq 3

        expect(contacts[0]['id']).to eq '8'
        expect(contacts[0]['Contact Information']['E-Mail']).to eq 'bobby@example.com'
        expect(contacts[0]['Lead Information']['Contact Owner']).to eq 'Jimbo Watunusi'

        expect(contacts[1]['id']).to eq '5'
        expect(contacts[1]['Contact Information']['E-Mail']).to eq 'ali@example.com'
        expect(contacts[1]['Lead Information']['Contact Owner']).to eq 'Jimbo Watunusi'
      end
    end
  end

  describe "#contacts_add" do
    it "returns the newly created contact" do
      contact_options = {
        'Contact Information' => {'First Name' => 'prashant', 'Last Name' => 'nadarajan', 'E-Mail' => 'prashant@example.com'},
        'Lead Information' => {'Contact Owner' => 'Don Corleone'}
      }

      request_contact_xml = @client.send(:xml_for_contact, contact_options)
      response_contact_xml = test_data('contacts_add_response.xml')

      request_body = request_body('add', 'return_id' => '1', 'data' => request_contact_xml)
      stub_request(:post, @contact_endpoint).with(:body => request_body).to_return(:body => response_contact_xml)

      contact = @client.contacts_add(contact_options)
      expect(WebMock).to have_requested(:post, @contact_endpoint).with(:body => request_body)

      expect(contact['id']).to eq '7'
      expect(contact['Contact Information']['First Name']).to eq 'prashant'
      expect(contact['Contact Information']['Last Name']).to eq 'nadarajan'
      expect(contact['Contact Information']['E-Mail']).to eq 'prashant@example.com'
      expect(contact['Lead Information']['Contact Owner']).to eq 'Don Corleone'
    end
  end

  describe "#contacts_pull_tag" do
    it "returns all the contact tag names and ids" do
      pull_tags_xml = test_data('contacts_pull_tags.xml')
      stub_request(:post, @contact_endpoint).with(:body => request_body('pull_tag')).to_return(:body => pull_tags_xml)

      tags = @client.contacts_pull_tag
      expect(tags['3']).to eq 'newleads'
      expect(tags['4']).to eq 'old_leads'
      expect(tags['5']).to eq 'legacy Leads'
    end
  end

  describe "#contacts_fetch_sequences" do
    it "returns all the available contact sequences" do
      xml = test_data('contacts_fetch_sequences.xml')
      stub_request(:post, @contact_endpoint).with(:body => request_body('fetch_sequences')).to_return(:body => xml)
      sequences = @client.contacts_fetch_sequences
      expect(sequences['3']).to eq 'APPOINTMENT REMINDER'
      expect(sequences['4']).to eq 'foo sequence'
    end
  end

  describe "#contacts_key" do
    it "returns information on the contact data structure" do
      xml = test_data('contacts_key_type.xml')
      stub_request(:post, @contact_endpoint).with(:body => request_body('key')).to_return(:body => xml)

      result = @client.contacts_key
      expect(result["Contact Information"]["editable"]).to be_falsey
      expect(result["Contact Information"]["fields"]["Cell Phone"]["editable"]).to be_falsey
      expect(result["Contact Information"]["fields"]["Cell Phone"]["type"]).to eq "phone"
      expect(result["Contact Information"]["fields"]["Birthday"]["type"]).to eq "fulldate"

      expect(result["Lead Information"]["fields"]["Lead Source"]["type"]).to eq "tdrop"
      expect(result["Lead Information"]["fields"]["Lead Source"]["options"][0]).to eq "Adwords"
      expect(result["Lead Information"]["fields"]["Lead Source"]["options"][4]).to eq "Newspaper Ad"

      expect(result["Sequences and Tags"]["fields"]["Contact Tags"]["type"]).to eq "list"
      expect(result["Sequences and Tags"]["fields"]["Contact Tags"]["list"]["5"]).to eq "legacy Leads"

      expect(result["PrecisoPro"]["editable"]).to be_truthy
      expect(result["PrecisoPro"]["fields"]["Lead Status"]["editable"]).to be_truthy
    end
  end

  describe "#contacts_fetch" do
    context "when all the ids exists" do
      it "returns the contacts" do
        xml_response = test_data('contacts_search_multiple_response.xml')
        xml_request = "<contact_id>8</contact_id><contact_id>5</contact_id><contact_id>7</contact_id>"
        stub_request(:post, @contact_endpoint).with(:body => request_body('fetch', 'data' => xml_request )).to_return(:body => xml_response)

        results = @client.contacts_fetch([8, 5, 7])
        expect(results.size).to eq 3
        expect(results[0]["Contact Information"]).not_to be_nil
      end
    end

    context "when some of the ids don't exist" do
      pending
    end

    context "when all the ids don't exist" do
      pending
    end
  end
end
