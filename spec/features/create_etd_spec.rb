# frozen_string_literal: true

RSpec.describe 'Create a new ETD', type: :feature do
  let(:etd_base_url) { 'etd-stage.stanford.edu' }
  # dissertation id must be unique; D followed by 9 digits, e.g. D123456789
  let(:dissertation_id) { format('D%09d', Kernel.rand(1..999_999_999)) }
  let(:dissertation_title) { 'Integration Testing of ETD Processing' }
  let(:xml_from_registrar) do
    # see https://github.com/sul-dlss/hydra_etd/wiki/Data-Creation-and-Interaction#creating-new-etd-records
    <<-XML
    <DISSERTATION>
      <dissertationid>#{dissertation_id}</dissertationid>
      <title>#{dissertation_title}</title>
      <type>Dissertation</type>
      <vpname>Patricia J. Gumport</vpname>
      <readerapproval>Not Submitted</readerapproval>
      <readercomment> </readercomment>
      <readeractiondttm> </readeractiondttm>
      <regapproval>Not Submitted</regapproval>
      <regactiondttm> </regactiondttm>
      <regcomment> </regcomment>
      <documentaccess>Yes</documentaccess>
      <schoolname>School of Medicine</schoolname>
      <degreeconfyr>2020</degreeconfyr>
      <reader>
        <sunetid>dedwards</sunetid>
        <name>Edwards, Doris</name>
        <type>int</type>
        <univid>05358772</univid>
        <readerrole>Doct Dissert Advisor (AC)</readerrole>
        <finalreader>Yes</finalreader>
      </reader>
      <reader type="int">
        <univid>05221995</univid>
        <sunetid>rkatila</sunetid>
        <name>Katila, Riitta</name>
        <readerrole>Doct Dissert Reader (AC)</readerrole>
        <finalreader>No</finalreader>
      </reader>
      <univid>05543256</univid>
      <sunetid>dkelley</sunetid>
      <name>Kelley, DeForest</name>
      <career code="MED">Medicine</career>
      <program code="MED">Medical</program>
      <plan code="ANT">Neurology</plan>
      <degree>PHD</degree>
    </DISSERTATION>
    XML
  end

  # may need to increase this: file uploads and submission to registrar
  # Capybara.default_max_wait_time = 5

  # See https://github.com/sul-dlss/hydra_etd/wiki/End-to-End-Testing-Procedure
  it do
    # registrar creates ETD in hydra_etd application by posting xml
    resp_body = simulate_registrar_post(xml_from_registrar)
    prefixed_druid = resp_body.split.first
    expect(prefixed_druid).to start_with('druid:')
    puts "dissertation id is #{dissertation_id}"
    puts "druid is #{prefixed_druid}"

    etd_submit_url = "https://#{etd_base_url}/submit/#{prefixed_druid}"
    puts "etd submit url: #{etd_submit_url}" # helpful for debugging
    authenticate!(start_url: etd_submit_url,
                  expected_text: "Dissertation ID : #{dissertation_id}")
    visit etd_submit_url

    # verify citation details
    expect(page.find('#pbCitationDetails')['style']).to eq '' # citation details not yet verified
    expect(page).to have_content(dissertation_id)
    expect(page).to have_content('Kelley, DeForest')
    expect(page).to have_content(dissertation_title)
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

    # fake reader approval
    reader_progress_list_el = all('#progressBoxContent > ol > li')[8]
    expect(reader_progress_list_el).to have_content('Verified by Final Reader - Not done')
    reader_approved = xml_from_registrar.dup.sub(/<readerapproval>Not Submitted<\/readerapproval>/,
                                                 '<readerapproval>Approved</readerapproval>')
    now = Time.now.strftime('%m/%d/%Y %T')
    reader_approved.sub!(/<readeractiondttm> <\/readeractiondttm>/, "<readeractiondttm>#{now}</readeractiondttm>")
    reader_approved.sub!(/<readercomment> <\/readercomment>/, '<readercomment>Spock approves</readercomment>')
    resp_body = simulate_registrar_post(reader_approved)
    expect(resp_body).to eq "#{prefixed_druid} updated"
    page.refresh # needed to show updated progress box
    reader_progress_list_el = all('#progressBoxContent > ol > li')[8]
    expect(reader_progress_list_el).to have_content('Verified by Final Reader - Done')

    # fake registrar approval
    registrar_progress_list_el = all('#progressBoxContent > ol > li')[9]
    expect(registrar_progress_list_el).to have_content('Approved by Registrar - Not done')
    registrar_approved = xml_from_registrar.dup.sub(/<regapproval>Not Submitted<\/regapproval>/,
                                                    '<regapproval>Approved</regapproval>')
    now = Time.now.strftime('%m/%d/%Y %T')
    registrar_approved.sub!(/<regactiondttm> <\/regactiondttm>/, "<regactiondttm>#{now}</regactiondttm>")
    resp_body = simulate_registrar_post(registrar_approved)
    expect(resp_body).to eq "#{prefixed_druid} updated"
    page.refresh # needed to show updated progress box
    registrar_progress_list_el = all('#progressBoxContent > ol > li')[9]
    expect(registrar_progress_list_el).to have_content('Approved by Registrar - Done')

    expect(page.find('#submissionApproved')).to have_content('Submission approved')

    # check Argo for object
    sleep(3) # waiting for Fedora/Solr
    visit "https://argo-stage.stanford.edu/view/#{prefixed_druid}"
    expect(page).to have_content dissertation_title
    apo_element = first('dd.blacklight-is_governed_by_ssim > a')
    expect(apo_element[:href]).to have_text('druid:bx911tp9024') # this is hardcoded in hydra_etd app
    status_element = first('dd.blacklight-status_ssi')
    expect(status_element).to have_text('v1 Registered')
    # sleep(15) # waiting for fedora/Solr to get embargo info so it shows up in Argo
    # page.refresh
    # expect(page).to have_content('This item is embargoed until')
    click_link('etdSubmitWF')
    modal_element = page.find('#blacklight-modal')
    # expect first 4 steps to have completed
    expect(modal_element).to have_content(/register-object completed/)
    expect(modal_element).to have_content(/submit completed/)
    expect(modal_element).to have_content(/reader-approval completed/)
    expect(modal_element).to have_content(/registrar-approval completed/)
    expect(modal_element).to have_content(/submit-marc waiting/)

    # TODO: the next etd wf steps are run by cron talking to symphony:  submit-marc, check-marc, catalog-status
    #  NOTE: these three steps will be migrating to hydra_etd app in the nearish future,
    #    which should make them testable within hydra_etd specs.  Also, the etdSubmitWF will likely go away
    #    and hydra_etd will be able to go through common-accessioning.

    # TODO: click over to argo and make sure accessioningWF is running

    # TODO: make sure accessioning completes cleanly (at least up to preservation robots steps)
  end
end

def simulate_registrar_post(xml)
  user = 'admindlss'
  password = 'p0stpl3as3'
  conn = Faraday.new(url: "https://#{user}:#{password}@#{etd_base_url}/etds")
  resp = conn.post do |req|
    req.options.timeout = 10
    req.options.open_timeout = 10
    req.headers['Content-Type'] = 'application/xml'
    req.body = xml
  end

  return resp.body if resp.success?

  raise "Error POSTing ETD: status #{resp.status}, #{resp.reason_phrase}, #{resp.body}"
end
