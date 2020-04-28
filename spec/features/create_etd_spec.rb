# frozen_string_literal: true

RSpec.describe 'Create a new ETD', type: :feature do
  now = '' # used for HEREDOC reader and registrar approved xml (can't be memoized)

  let(:etd_base_url) { 'etd-stage.stanford.edu' }
  # dissertation id must be unique; D followed by 9 digits, e.g. D123456789
  let(:dissertation_id) { format('D%09d', Kernel.rand(1..999_999_999)) }
  let(:random_title_word) { RandomWord.nouns.next }
  let(:dissertation_title) { "Integration Testing of ETD Processing - #{random_title_word}" }
  let(:random_author_word) { RandomWord.nouns.next }
  let(:dissertation_author) { "Kelly, DeForest #{random_author_word}" }
  let(:initial_xml_from_registrar) do
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
      <name>#{dissertation_author}</name>
      <career code="MED">Medicine</career>
      <program code="MED">Medical</program>
      <plan code="ANT">Neurology</plan>
      <degree>PHD</degree>
    </DISSERTATION>
    XML
  end
  let(:reader_approval_xml_from_registrar) do
    reader_approved = initial_xml_from_registrar.dup.sub(%r{<readerapproval>Not Submitted</readerapproval>},
                                                         '<readerapproval>Approved</readerapproval>')
    reader_approved.sub!(%r{<readeractiondttm> </readeractiondttm>}, "<readeractiondttm>#{now}</readeractiondttm>")
    reader_approved.sub!(%r{<readercomment> </readercomment>}, '<readercomment>Spock approves</readercomment>')
  end
  let(:registrar_approval_xml_from_registrar) do
    registrar_approved = reader_approval_xml_from_registrar.dup.sub(%r{<regapproval>Not Submitted</regapproval>},
                                                                    '<regapproval>Approved</regapproval>')
    registrar_approved.sub!(%r{<regactiondttm> </regactiondttm>}, "<regactiondttm>#{now}</regactiondttm>")
  end
  let(:abstract_text) { 'this is the abstract text' }
  let(:dissertation_filename) { 'etd_dissertation.pdf' }
  let(:supplemental_filename) { 'etd_supplemental.txt' }
  let(:permissions_filename) { 'etd_permissions.pdf' }

  # See https://github.com/sul-dlss/hydra_etd/wiki/End-to-End-Testing-Procedure
  it do
    # registrar creates ETD in hydra_etd application by posting xml
    resp_body = simulate_registrar_post(initial_xml_from_registrar)
    prefixed_druid = resp_body.split.first
    expect(prefixed_druid).to start_with('druid:')
    # puts "dissertation id is #{dissertation_id}" # helpful for debugging
    # puts "druid is #{prefixed_druid}" # helpful for debugging

    etd_submit_url = "https://#{etd_base_url}/submit/#{prefixed_druid}"
    # puts "etd submit url: #{etd_submit_url}" # helpful for debugging
    authenticate!(start_url: etd_submit_url,
                  expected_text: "Dissertation ID : #{dissertation_id}")
    visit etd_submit_url

    # verify citation details
    expect(page).to have_selector('#pbCitationDetails', text: 'Citation details verified - Not done')
    expect(page).not_to have_a_complete_step('#pbCitationDetails')
    expect(page).to have_content(dissertation_id)
    expect(page).to have_content(dissertation_author)
    expect(page).to have_content(dissertation_title)
    check('confirmCitationDetails')
    expect(page).to have_a_complete_step('#pbCitationDetails')

    # provide abstract
    expect(page).to have_selector('#pbAbstractProvided', text: 'Abstract provided - Not done')
    expect(page).not_to have_a_complete_step('#pbAbstractProvided')
    within '#submissionSteps' do
      step_list = all('div.step')
      within step_list[1] do
        find('div#textareaAbstract').click
        fill_in 'textareaAbstract_edit', with: abstract_text
        click_button 'Save'
      end
    end
    expect(page).to have_content(abstract_text)
    expect(page).to have_a_complete_step('#pbAbstractProvided')

    # the hydra_etd app has all the <input type=file> tags at the bottom of the page, disabled,
    #   and when uploading files, we have to attach the file to the right one of these elements
    #   This is probably an artifact of the js framework it uses, prototype
    file_upload_elements = all('input[type=file]', visible: false)

    # upload dissertation PDF
    expect(page).not_to have_content(dissertation_filename)
    expect(page).to have_selector('#pbDissertationUploaded', text: 'Dissertation uploaded - Not done')
    expect(page).not_to have_a_complete_step('#pbDissertationUploaded')
    dissertation_pdf_upload_input = file_upload_elements.first
    dissertation_pdf_upload_input.attach_file("spec/fixtures/#{dissertation_filename}")
    expect(page).to have_content(dissertation_filename)
    expect(page).to have_a_complete_step('#pbDissertationUploaded')

    # upload supplemental file
    expect(page).not_to have_content(supplemental_filename)
    expect(page).to have_selector('#pbSupplementalFilesUploaded', visible: :hidden)
    check('My dissertation includes supplemental files.')
    supplemental_upload_input = file_upload_elements[1]
    supplemental_upload_input.attach_file("spec/fixtures/#{supplemental_filename}")
    expect(page).to have_content(supplemental_filename)
    expect(page).to have_selector('#pbSupplementalFilesUploaded', visible: true)
    expect(page).to have_a_complete_step('#pbSupplementalFilesUploaded')

    # indicate copyrighted material
    expect(page).to have_selector('#pbPermissionsProvided', text: 'Copyrighted material checked - Not done')
    expect(find('#pbPermissionsProvided')['style']).to eq '' # rights not yet selected
    select 'does include', from: 'selectPermissionsOptions'

    # provide copyright permissions letters/files
    expect(page).not_to have_content(permissions_filename)
    expect(page).to have_selector('#pbPermissionFilesUploaded', visible: :hidden)
    permissions_upload_input = file_upload_elements[11]
    permissions_upload_input.attach_file("spec/fixtures/#{permissions_filename}")
    expect(page).to have_content(permissions_filename)
    expect(page).to have_selector('#pbPermissionFilesUploaded', visible: true)

    expect(page).to have_a_complete_step('#pbPermissionFilesUploaded')
    expect(page).to have_a_complete_step('#pbPermissionsProvided')

    # apply licenses
    expect(page).to have_selector('#pbRightsSelected', text: 'License terms applied - Not done')
    expect(page.find('#pbRightsSelected')['style']).to eq '' # rights not applied yet
    click_link 'View Stanford University publication license'
    check 'I have read and agree to the terms of the Stanford University license.'
    click_link 'Close this window'
    click_link 'View Creative Commons licenses'
    select 'CC Attribution license', from: 'selectCCLicenseOptions'
    click_link 'Close this window'

    # set embargo
    click_link 'Postpone release'
    select '6 months', from: 'selectReleaseDelayOptions'
    click_link 'Close this window'

    expect(page).to have_a_complete_step('#pbRightsSelected')

    accept_alert do
      click_button 'Submit to Registrar'
    end
    expect(page).to have_selector('#submissionSuccessful', text: 'Submission successful')
    expect(page).to have_selector('#submitToRegistrarDiv > p.progressItemChecked', text: 'Submitted')

    # page has reloaded with submit to registrar and these now will show as updated
    expect(page).to have_selector('#pbCitationDetails', text: 'Citation details verified - Done')
    expect(page).to have_selector('#pbAbstractProvided', text: 'Abstract provided - Done')
    expect(page).to have_selector('#pbDissertationUploaded', text: 'Dissertation uploaded - Done')
    expect(page).to have_selector('#pbSupplementalFilesUploaded', text: 'Supplemental files uploaded - Done')
    expect(page).to have_selector('#pbPermissionsProvided', text: 'Copyrighted material checked - Done')
    expect(page).to have_selector('#pbPermissionFilesUploaded', text: 'Permission files uploaded - Done')
    expect(page).to have_selector('#pbRightsSelected', text: 'License terms applied - Done')

    # fake reader approval
    reader_progress_list_el = all('#progressBoxContent > ol > li')[8]
    expect(reader_progress_list_el).to have_text('Verified by Final Reader - Not done')
    now = Time.now.strftime('%m/%d/%Y %T')
    resp_body = simulate_registrar_post(reader_approval_xml_from_registrar)
    expect(resp_body).to eq "#{prefixed_druid} updated"
    page.refresh # needed to show updated progress box
    reader_progress_list_el = all('#progressBoxContent > ol > li')[8]
    expect(reader_progress_list_el).to have_text('Verified by Final Reader - Done')

    # fake registrar approval
    registrar_progress_list_el = all('#progressBoxContent > ol > li')[9]
    expect(registrar_progress_list_el).to have_text('Approved by Registrar - Not done')
    now = Time.now.strftime('%m/%d/%Y %T')
    resp_body = simulate_registrar_post(registrar_approval_xml_from_registrar)
    expect(resp_body).to eq "#{prefixed_druid} updated"
    page.refresh # needed to show updated progress box
    registrar_progress_list_el = all('#progressBoxContent > ol > li')[9]
    expect(registrar_progress_list_el).to have_text('Approved by Registrar - Done')

    expect(page).to have_selector('#submissionApproved', text: 'Submission approved')

    # check Argo for object (wait for embargo info)
    Timeout.timeout(100) do
      loop do
        visit "https://argo-stage.stanford.edu/view/#{prefixed_druid}"
        break if page.has_text?('This item is embargoed until')
      end
    end
    expect(page).to have_content(dissertation_title)
    apo_element = first('dd.blacklight-is_governed_by_ssim > a')
    expect(apo_element[:href]).to have_text('druid:bx911tp9024') # this is hardcoded in hydra_etd app
    status_element = first('dd.blacklight-status_ssi')
    expect(status_element).to have_text('v1 Registered')
    click_link('etdSubmitWF')
    modal_element = find('#blacklight-modal')
    # expect first 4 steps to have completed
    expect(modal_element).to have_text(/register-object completed/)
    expect(modal_element).to have_text(/submit completed/)
    expect(modal_element).to have_text(/reader-approval completed/)
    expect(modal_element).to have_text(/registrar-approval completed/)
    expect(modal_element).to have_text(/submit-marc waiting/)

    # TODO: the next etd wf steps are run by cron talking to symphony:  submit-marc, check-marc, catalog-status
    #  NOTE: these three steps will be migrating to hydra_etd app in the nearish future,
    #    which should make them testable within hydra_etd specs.  Also, the etdSubmitWF will likely go away
    #    and hydra_etd will be able to go through common-accessioning.

    # TODO: click over to argo and make sure accessioningWF is running

    # TODO: make sure accessioning completes cleanly (at least up to preservation robots steps)
  end
end

def simulate_registrar_post(xml)
  @user ||= ENV['ETD_POST_USERNAME']
  @password ||= ENV['ETD_POST_PASSWORD']
  conn = Faraday.new(url: "https://#{@user}:#{@password}@#{etd_base_url}/etds")
  resp = conn.post do |req|
    req.options.timeout = 10
    req.options.open_timeout = 10
    req.headers['Content-Type'] = 'application/xml'
    req.body = xml
  end

  return resp.body if resp.success?

  raise "Error POSTing ETD: status #{resp.status}, #{resp.reason_phrase}, #{resp.body}"
end
