# frozen_string_literal: true

RSpec.describe 'Create a new ETD', type: :feature do
  let(:etd_base_url) { 'etd-stage.stanford.edu' }
  # dissertation id must be unique; D followed by 9 digits, e.g. D123456789
  let(:dissertation_id) { "D%09d" % Kernel.rand(1..999999999) }
  let(:xml_from_registrar) do
    # see https://github.com/sul-dlss/hydra_etd/wiki/Data-Creation-and-Interaction#creating-new-etd-records
    <<-XML
    <DISSERTATION>
      <dissertationid>#{dissertation_id}</dissertationid>
      <title>Integration Testing of ETD Processing</title>
      <type>Dissertation</type>
      <vpname>Patricia J. Gumport</vpname>
      <readerapproval>Not Submitted</readerapproval>
      <readercomment/>
      <readeractiondttm/>
      <regapproval>Not Submitted</regapproval>
      <regactiondttm/>
      <regcomment/>
      <documentaccess>Yes</documentaccess>
      <schoolname>School of Medicine</schoolname>
      <degreeconfyr>2020</degreeconfyr>
      <reader>
        <sunetid>dedwards</sunetid>
        <prefix/>
        <name>Edwards, Doris</name>
        <suffix/>
        <type>int</type>
        <univid>05358772</univid>
        <readerrole>Doct Dissert Co-Adv (AC)</readerrole>
        <finalreader>Yes</finalreader>
      </reader>
      <univid>05543256</univid>
      <sunetid>lforest</sunetid>
      <name>Forest, Lester</name>
      <career code="MED">Medicine</career>
      <program code="MED">Medical</program>
      <plan code="ANT">Neurology</plan>
      <degree>PHD</degree>
      <subplan code="" />
    </DISSERTATION>
    XML
  end

  scenario do
    # registrar creates ETD in hydra_etd app by posting xml
    resp_body = simulate_registrar_post(xml_from_registrar)
    prefixed_druid = resp_body.split.first
    puts "DRUID CREATED: #{prefixed_druid}"
    expect(prefixed_druid).to start_with('druid:')

    etd_submit_url = "https://#{etd_base_url}/submit/#{prefixed_druid}"
    authenticate!(start_url: etd_submit_url,
                  expected_text: "Dissertation ID : #{dissertation_id}")
    visit etd_submit_url

    # verify citation details
    expect(page.find('#pbCitationDetails')['style']).to eq '' # citation details not yet verified
    expect(page).to have_content(dissertation_id)
    expect(page).to have_content("Forest, Lester")
    expect(page).to have_content("Integration Testing of ETD Processing")
    check('confirmCitationDetails')
    # a checked box in the progress section is a background image
    expect(page.find('#pbCitationDetails')['style']).to match(/background-image/)

    # provide abstract
    expect(page.find('#pbAbstractProvided')['style']).to eq '' # abstract not yet provided
    within '#submissionSteps' do
      step_list = all('div.step')

      within step_list[1] do
        find('div#textareaAbstract').click
        abstract_text = 'this is the abstract text'
        fill_in 'textareaAbstract_edit', with: abstract_text
        click_button 'Save'
      end
    end
    # a checked box in the progress section is a background image
    expect(page.find('#pbAbstractProvided')['style']).to match(/background-image/)

    # upload dissertation PDF


    # provide supplemental file


    # indicate copyright
    # provide permission file

    # apply license(s)



    # "submit etd to registrar" ??

    # fake registrar approval

    # trigger etdSubmitWF:submit-marc robot processing

    # step 6:  these are documented in data creation wiki - post more shitty xml

    # verify things look right on etd side -- checkmarks are there

    # some etd wf steps are run by cron -- not sure what to do with this.   (checking symphony)

    # then click over to argo and make sure accessioningWF is running

  end


end


# this simulates an ETD submission by the registrar
def simulate_registrar_post(xml)
  user =  'admindlss'
  password = 'p0stpl3as3'
  conn = Faraday.new(url: "https://#{user}:#{password}@#{etd_base_url}/etds")
  resp = conn.post do |req|
    req.options.timeout = 10
    req.options.open_timeout = 10
    req.headers['Content-Type'] = 'application/xml'
    req.body = xml
  end

  return resp.body if resp.success?

  errmsg = "Unable to create ETD: status #{resp.status}, #{resp.reason_phrase}, #{resp.body}"
  raise(RuntimeError, errmsg)
end
