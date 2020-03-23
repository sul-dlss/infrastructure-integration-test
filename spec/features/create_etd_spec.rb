# frozen_string_literal: true

RSpec.describe 'Create a new ETD', type: :feature, js: true do
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

  # may need to increase this: file uploads and submission to registrar
  # Capybara.default_max_wait_time = 5

  # See https://github.com/sul-dlss/hydra_etd/wiki/End-to-End-Testing-Procedure
  scenario do
    # registrar creates ETD in hydra_etd application by posting xml
    resp_body = simulate_registrar_post(xml_from_registrar)
    prefixed_druid = resp_body.split.first
    expect(prefixed_druid).to start_with('druid:')
    puts "druid is #{prefixed_druid}"

    etd_submit_url = "https://#{etd_base_url}/submit/#{prefixed_druid}"
    puts "etd submit url: #{etd_submit_url}" # helpful for debugging
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
    abstract_text = 'this is the abstract text'
    within '#submissionSteps' do
      step_list = all('div.step')
      within step_list[1] do
        find('div#textareaAbstract').click
        fill_in 'textareaAbstract_edit', with: abstract_text
        click_button 'Save'
      end
    end
    # a checked box in the progress section is a background image and has class .progressItemChecked
    expect(page).to have_content(abstract_text)
    expect(page.find('#pbAbstractProvided')['style']).to match(/background-image/)

    # the hydra_etd app has all the <input type=file> tags at the bottom of the page, disabled,
    #   and when uploading files, we have to attach the file to the right one of these elements
    #   I think this may be an artifact of the js framework it usees, prototype
    file_upload_elements = all('input[type=file]', visible: false)

    # upload dissertation PDF
    filename = 'etd_dissertation.pdf'
    expect(page.find('#pbDissertationUploaded')['style']).to eq '' # dissertation PDF not yet provided
    expect(page).not_to have_content(filename)
    dissertation_pdf_upload_input = file_upload_elements.first
    dissertation_pdf_upload_input.attach_file("spec/fixtures/#{filename}")
    sleep(3) # wait for upload
    expect(page).to have_content(filename)
    # a checked box in the progress section is a background image
    expect(page.find('#pbDissertationUploaded')['style']).to match(/background-image/)

    # upload supplemental file
    find('input#cbSupplementalFiles').check
    filename = 'etd_supplemental.txt'
    expect(page).not_to have_content(filename)
    # supplemental files uploaded progress checkbox not visible by default
    expect(page.find('#pbSupplementalFilesUploaded', visible: false)).not_to be_visible
    supplemental_upload_input = file_upload_elements[1]
    supplemental_upload_input.attach_file("spec/fixtures/#{filename}")
    expect(page).to have_content(filename)
    # a checked box in the progress section is a background image
    expect(page.find('#pbSupplementalFilesUploaded')['style']).to match(/background-image/)

    # indicate copyrighted material
    expect(page.find('#pbPermissionsProvided')['style']).to eq '' # rights not yet selected
    page.select 'does include', from: 'selectPermissionsOptions'

    # provide copyright permissions letters/files
    # permission files uploaded progress checkbox not visible by default
    expect(page.find('#pbPermissionFilesUploaded', visible: false)).not_to be_visible
    filename = 'etd_permissions.pdf'
    expect(page).not_to have_content(filename)
    permissions_upload_input = file_upload_elements[11]
    permissions_upload_input.attach_file("spec/fixtures/#{filename}")
    expect(page).to have_content(filename)
    # a checked box in the progress section is a background image
    expect(page.find('#pbPermissionsProvided')['style']).to match(/background-image/)
    expect(page.find('#pbPermissionFilesUploaded')).to be_instance_of Capybara::Node::Element

    # apply licenses
    expect(page.find('#pbRightsSelected')['style']).to eq '' # rights not applied yet
    click_link('View Stanford University publication license')
    page.find('input#cbLicenseStanford').check
    click_link('Close this window')
    click_link('View Creative Commons licenses')
    page.select 'CC Attribution license', from: 'selectCCLicenseOptions'
    click_link('Close this window')

    # set embargo
    click_link('Postpone release')
    page.select '6 months', from: 'selectReleaseDelayOptions'
    click_link('Close this window')

    expect(page.find('#pbRightsSelected')['style']).to match(/background-image/)

    # "submit etd to registrar"
    accept_alert do
      page.find('#submitToRegistrar').click # javascript
    end
    # page.find waits for this element to appear
    expect(page.find('#submissionSuccessful')).to have_content('Submission successful')
    expect(page.find('#submitToRegistrarDiv > p.progressItemChecked')).to have_content('Submitted')

    # fake registrar approval
    # expect(page.find('#submitToRegistrarDiv')['style']).to match(/background-image/)

    # trigger etdSubmitWF:submit-marc robot processing

    # step 6:  these are documented in data creation wiki - post more shitty xml
    # some etd wf steps are run by cron -- not sure what to do with this.   (checking symphony)

    # then click over to argo and make sure accessioningWF is running (and maybe completes?)

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
