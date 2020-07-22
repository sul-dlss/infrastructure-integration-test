# frozen_string_literal: true

require 'dor/services/client'
require 'dor/workflow/client'

RSpec.describe 'Create a new ETD', type: :feature do
  now = '' # used for HEREDOC reader and registrar approved xml (can't be memoized)
  prefixed_druid = ''

  # dissertation id must be unique; D followed by 9 digits, e.g. D123456789
  let(:dissertation_id) { format('%10d', Kernel.rand(1..9_999_999_999)) }
  let(:random_title_word) { RandomWord.nouns.next }
  let(:dissertation_title) { "Integration Testing of ETD Processing - #{random_title_word}" }
  let(:random_author_word) { RandomWord.nouns.next }
  let(:dissertation_author) { "Kelly, DeForest #{random_author_word}" }
  let(:dissertation_type) { 'Dissertation' }
  let(:initial_xml_from_registrar) do
    # see https://github.com/sul-dlss/hydra_etd/wiki/Data-Creation-and-Interaction#creating-new-etd-records
    <<-XML
    <DISSERTATION>
      <dissertationid>#{dissertation_id}</dissertationid>
      <title>#{dissertation_title}</title>
      <type>#{dissertation_type}</type>
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
        <univid>12345</univid>
        <readerrole>Doct Dissert Advisor (AC)</readerrole>
        <finalreader>Yes</finalreader>
      </reader>
      <reader type="int">
        <univid>54321</univid>
        <sunetid>rkatila</sunetid>
        <name>Katila, Riitta</name>
        <readerrole>Doct Dissert Reader (AC)</readerrole>
        <finalreader>No</finalreader>
      </reader>
      <univid>33333</univid>
      <sunetid>#{AuthenticationHelpers.username}</sunetid>
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
  let(:bare_druid) { prefixed_druid.split('druid:').last }
  let(:generated_content_metadata) do
    <<-XML
      <contentMetadata type="file" objectId="#{prefixed_druid}">
        <resource id="ab123cd4567_1" type="main-original">
          <attr name="label">Body of dissertation (as submitted)</attr>
          <file id="#{dissertation_filename}" mimetype="application/pdf" size="1634" shelve="yes" publish="no" preserve="yes">
            <checksum type="md5">f7169731f4c163f98eed35e1be12a209</checksum>
            <checksum type="sha1">c9fbb6eaf4549da5a798e50eeb376b167042db9a</checksum>
          </file>
        </resource>
        <resource id="#{bare_druid}_2" type="main-augmented" objectId="">
          <attr name="label">Body of dissertation</attr>
          <file id="#{dissertation_filename}-augmented.pdf" mimetype="application/pdf" size="8336" shelve="yes" publish="yes" preserve="yes">
            <checksum type="md5">56ffb383d08abe5e3a99494a1ef72afa</checksum>
            <checksum type="sha1">8a2232b27aa5347fb86ef9878a4997008699a2ff</checksum>
          </file>
        </resource>
        <resource id="#{bare_druid}_3" type="supplement" sequence="1">
          <file id="#{supplemental_filename}" mimetype="text/plain" size="59" shelve="yes" publish="yes" preserve="yes">
            <checksum type="md5">06b92ab61a355d6efb95629b18801164</checksum>
            <checksum type="sha1">2ae1de5a7386824fd2ca47e04a6733dd249ca312</checksum>
          </file>
        </resource>
        <resource id="#{bare_druid}_4" type="permissions">
          <file id="#{permissions_filename}" mimetype="application/pdf" size="1634" shelve="yes" publish="no" preserve="yes">
            <checksum type="md5">f7169731f4c163f98eed35e1be12a209</checksum>
            <checksum type="sha1">c9fbb6eaf4549da5a798e50eeb376b167042db9a</checksum>
          </file>
        </resource>
      </contentMetadata>
    XML
  end
  let(:generated_rights_metadata) do
    <<-XML
      <rightsMetadata objectId="#{prefixed_druid}">
        <copyright>
          <human>(c) Copyright 2016 by Midge Klump</human>
        </copyright>
        <access type="discover">
          <machine>
            <world/>
          </machine>
        </access>
        <access type="read">
          <machine>
            <group>stanford</group>
          </machine>
        </access>
        <use>
          <machine type="creativeCommons">none</machine>
          <human type="creativeCommons"></human>
        </use>
      </rightsMetadata>
    XML
  end

  # See https://github.com/sul-dlss/hydra_etd/wiki/End-to-End-Testing-Procedure
  scenario do
    authenticate!(start_url: "#{Settings.etd_url}/view/0001",
                  expected_text: 'Could not find an Etd with id: 0001')

    # registrar creates ETD in hydra_etd application by posting xml
    resp_body = simulate_registrar_post(initial_xml_from_registrar)
    prefixed_druid = resp_body.split.first
    expect(prefixed_druid).to start_with('druid:')
    # puts "dissertation id is #{dissertation_id}" # helpful for debugging
    # puts "druid is #{prefixed_druid}" # helpful for debugging

    etd_submit_url = "#{Settings.etd_url}/submit/#{prefixed_druid}"
    # puts "etd submit url: #{etd_submit_url}" # helpful for debugging
    visit etd_submit_url

    # verify citation details
    expect(page).to have_selector('#pbCitationDetails', text: "Citation details verified\n- Not done")
    expect(page).not_to have_a_complete_step('#pbCitationDetails')
    expect(page).to have_content(dissertation_id)
    expect(page).to have_content(dissertation_author)
    expect(page).to have_content(dissertation_title)
    check('confirmCitationDetails')
    expect(page).to have_a_complete_step('#pbCitationDetails')

    # provide abstract
    expect(page).to have_selector('#pbAbstractProvided', text: "Abstract provided\n- Not done")
    expect(page).not_to have_a_complete_step('#pbAbstractProvided')
    fill_in 'Enter your abstract in plain text (no HTML or special formatting, such as bullets or indentation).',
            with: abstract_text
    click_button 'Save'
    expect(page).to have_a_complete_step('#pbAbstractProvided')

    # confirm format has been reviewed
    expect(page).not_to have_a_complete_step('#pbFormatReviewed')
    expect(page).to have_selector('#pbFormatReviewed', text: "Format reviewed\n- Not done")
    check('confirmFormatReview')
    expect(page).to have_a_complete_step('#pbFormatReviewed')

    # the hydra_etd app has all the <input type=file> tags at the bottom of the page, disabled,
    #   and when uploading files, we have to attach the file to the right one of these elements
    #   This is probably an artifact of the js framework it uses, prototype
    file_upload_elements = all('input[type=file]', visible: :all)

    # upload dissertation PDF
    expect(page).not_to have_content(dissertation_filename)
    expect(page).to have_selector('#pbDissertationUploaded', text: "Dissertation uploaded\n- Not done")
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
    expect(page).to have_selector('#pbSupplementalFilesUploaded', visible: :visible)
    expect(page).to have_a_complete_step('#pbSupplementalFilesUploaded')

    # indicate copyrighted material
    expect(page).to have_selector('#pbPermissionsProvided', text: "Copyrighted material checked\n- Not done")
    expect(find('#pbPermissionsProvided')['style']).to eq '' # rights not yet selected
    select 'Yes', from: "My #{dissertation_type.downcase} contains copyright material"

    # provide copyright permissions letters/files
    expect(page).not_to have_content(permissions_filename)
    expect(page).to have_selector('#pbPermissionFilesUploaded', visible: :hidden)
    permissions_upload_input = file_upload_elements[11]
    permissions_upload_input.attach_file("spec/fixtures/#{permissions_filename}")
    expect(page).to have_content(permissions_filename)
    expect(page).to have_selector('#pbPermissionFilesUploaded', visible: :visible)

    expect(page).to have_a_complete_step('#pbPermissionFilesUploaded')
    expect(page).to have_a_complete_step('#pbPermissionsProvided')

    # apply licenses
    expect(page).to have_selector('#pbRightsSelected', text: "License terms applied\n- Not done")
    expect(page.find('#pbRightsSelected')['style']).to eq '' # rights not applied yet
    click_link 'View Stanford University publication license'
    check 'I have read and agree to the terms of the Stanford University license.'
    click_button 'Close'
    click_link 'View Creative Commons licenses'
    select 'CC Attribution license', from: 'selectCCLicenseOptions'
    click_button 'Close'

    # set embargo
    click_link 'Postpone release'
    select '6 months', from: 'selectReleaseDelayOptions'
    click_button 'Close'

    expect(page).to have_a_complete_step('#pbRightsSelected')

    accept_alert do
      click_button 'Submit to Registrar'
    end
    expect(page).to have_selector('#submissionSuccessful', text: 'Submission successful')
    expect(page).to have_selector('#submitToRegistrarDiv > p.progressItemChecked', text: 'Submitted')

    # page has reloaded with submit to registrar and these now will show as updated
    expect(page).to have_selector('#pbCitationDetails', text: "Citation details verified\n- Done")
    expect(page).to have_selector('#pbAbstractProvided', text: "Abstract provided\n- Done")
    expect(page).to have_selector('#pbFormatReviewed', text: "Format reviewed\n- Done")
    expect(page).to have_selector('#pbDissertationUploaded', text: "Dissertation uploaded\n- Done")
    expect(page).to have_selector('#pbSupplementalFilesUploaded', text: "Supplemental files uploaded\n- Done")
    expect(page).to have_selector('#pbPermissionsProvided', text: "Copyrighted material checked\n- Done")
    expect(page).to have_selector('#pbPermissionFilesUploaded', text: "Permission files uploaded\n- Done")
    expect(page).to have_selector('#pbRightsSelected', text: "License terms applied\n- Done")

    # fake reader approval
    reader_progress_list_el = all('#progressBoxContent > ol > li')[9]
    expect(reader_progress_list_el).to have_text("Verified by Final Reader\n- Not done")
    now = Time.now.in_time_zone('America/Los_Angeles').strftime('%m/%d/%Y %T')
    resp_body = simulate_registrar_post(reader_approval_xml_from_registrar)
    expect(resp_body).to eq "#{prefixed_druid} updated"
    page.refresh # needed to show updated progress box
    reader_progress_list_el = all('#progressBoxContent > ol > li')[9]
    expect(reader_progress_list_el).to have_text("Verified by Final Reader\n- Done")

    # fake registrar approval
    registrar_progress_list_el = all('#progressBoxContent > ol > li')[10]
    expect(registrar_progress_list_el).to have_text("Approved by Registrar\n- Not done")
    now = Time.now.in_time_zone('America/Los_Angeles').strftime('%m/%d/%Y %T')
    resp_body = simulate_registrar_post(registrar_approval_xml_from_registrar)
    expect(resp_body).to eq "#{prefixed_druid} updated"
    page.refresh # needed to show updated progress box
    registrar_progress_list_el = all('#progressBoxContent > ol > li')[10]
    expect(registrar_progress_list_el).to have_text("Approved by Registrar\n- Done")

    expect(page).to have_selector('#submissionApproved', text: 'Submission approved')

    # check Argo for object (wait for embargo info)
    Timeout.timeout(Settings.timeouts.workflow) do
      loop do
        visit "#{Settings.argo_url}/view/#{prefixed_druid}"
        break if page.has_text?('This item is embargoed until', wait: 1)
      end
    end
    expect(page).to have_content(dissertation_title)
    apo_element = first('dd.blacklight-is_governed_by_ssim > a')
    expect(apo_element[:href]).to have_text('druid:bx911tp9024') # this is hardcoded in hydra_etd app
    status_element = first('dd.blacklight-status_ssi')
    expect(status_element).to have_text('v1 Registered')
    click_link('etdSubmitWF')
    modal_element = find('#blacklight-modal')
    # expect first 5 etdSubmitWF steps to have completed
    expect(modal_element).to have_text(/register-object completed/)
    expect(modal_element).to have_text(/submit completed/)
    expect(modal_element).to have_text(/reader-approval completed/)
    expect(modal_element).to have_text(/registrar-approval completed/)
    expect(modal_element).to have_text(/submit-marc completed/)
    expect(modal_element).to have_text(/check-marc waiting/)
    click_button('Cancel')

    # we simulate the check-marc etdSubmitWF step because its pre-conditions are:
    # 1. etd cron job has taken MARC stub record from submit-marc step and combined it into the daily file
    # 2. Symphony (ILS) cron job has loaded the daily file of stubbed MARC records with ours in it
    simulate_check_marc(prefixed_druid)
    # Timeout.timeout(Settings.timeouts.workflow) do
    #   loop do
    #     page.click_button('Cancel')
    #     click_link('etdSubmitWF')
    #     modal_element = find('#blacklight-modal')
    #     break if modal_element.has_text?(/check-marc completed/, wait: 1)
    #   end
    # end

    # we simulate the remaining etdSubmitWF steps because they all require external
    #  circumstances to this app:
    # - catalog-status: requires cataloger to update Marc record in symphony, and cron job to notice
    # - other-metadata: triggered as a background job as the last part of catalog-status code in ETD app
    # - start-accession: triggered as a background job as the last part of otherMetadataJob in ETD app
    # since we cannot update the WF directly, we will ignore it
    simulate_other_metadata(prefixed_druid)

    # The ETD app programmatically adds the accessionWF; we add it manually
    find_link('Add workflow').click
    select 'accessionWF', from: 'wf'
    find_button('Add').click

    # wait for accessioningWF to finish
    reload_page_until_timeout!(text: 'v1 Accessioned')

    # TODO: check descMetadata, identityMetadata?
  end
end

def simulate_registrar_post(xml)
  conn = Faraday.new(url: "#{Settings.etd_url}/etds")
  conn.basic_auth(Settings.etd.username, Settings.etd.password)
  resp = conn.post do |req|
    req.options.timeout = 10
    req.options.open_timeout = 10
    req.headers['Content-Type'] = 'application/xml'
    req.body = xml
  end

  return resp.body if resp.success?

  raise "Error POSTing ETD: status #{resp.status}, #{resp.reason_phrase}, #{resp.body}"
end

# Execute code from the check-marc robot in the ETD app, which is run by a cron job.
# EXCEPT: we are hard-coding the catkey, since no cataloging will take place for this test
# See https://github.com/sul-dlss/hydra_etd/blob/master/app/services/check_marc.rb
def simulate_check_marc(druid)
  catkey = '3060835' # an ETD (pre-etd app, but whatevs) in both prod and non-prod ILS
  object_client = dor_services_object_client(druid)
  dro = object_client.find # returns cocina metadata
  dro_as_hash = dro.to_h
  dro_as_hash[:structural][:hasAgreement] = 'druid:ct692vv3660' # ETD deposit agreement object
  dro_as_hash[:identification][:catalogLinks] = [{ catalog: 'symphony', catalogRecordId: catkey }]
  object_client.update(params: dro_as_hash)
  # Set the etdSubmitWF step to completed, as the robot would
#  workflow_step_completed('check-marc', druid)
end

# Execute code for the otherMetadataJob - a background job that
#   is kicked off by the code for the previous catalog-status etdSubmitWF step, and that ends
#   by kicking off a background to run the start-accession step in etdSubmitWF
# Execute the code here for the other-metadata etdSubmitWF step in the ETD app.
# The ETD app runs other-metadata as a background job; we must rMetadataJob steps we are forcing otherMetadataJob to run, as it is kicked off as a background job as the last
#  thing in catalog-status
def simulate_other_metadata(druid)
  object_client = dor_services_object_client(druid)
  object_client.refresh_metadata
  object_client.metadata.legacy_update(
    content: {
      updated: Time.now,
      content: generated_content_metadata
    },
    rights: {
      updated: Time.now,
      content: generated_rights_metadata
    }
  )
  object_client.administrative_tags.create(tags: ['ETD : Dissertation'])
  # workflow_step_completed('other-metadata', druid)
  # simulate_start_accession
end

def dor_services_object_client(druid)
  @dor_services_client ||= begin
    Dor::Services::Client.configure(url: Settings.dor_services_app.url,
                                    token: Settings.dor_services_app.token)
  end
  @object_client ||= @dor_services_client.object(druid)
end

# Set an etdSubmitWF step to completed (as a robot would)
def workflow_step_completed(step, druid)
  # FIXME:  it hangs here because no TCP access allowed.
  # See section in README and also see https://github.com/sul-dlss/operations-tasks/issues/2301
  workflow_client.update_status(druid: druid,
                                workflow: 'etdSubmitWF',
                                process: step,
                                status: 'completed')
end

def workflow_client
  @workflow_client ||= Dor::Workflow::Client.new(url: Settings.workflow.url,
                                                 logger: Settings.workflow.logfile,
                                                 timeout: Settings.timeouts.workflow)
end
