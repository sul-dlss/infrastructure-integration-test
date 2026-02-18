# frozen_string_literal: true

# Integration: ETD, Argo, DSA
RSpec.describe 'Create a new ETD with embargo, and then update the embargo date' do
  now = '' # used for HEREDOC reader and registrar approved xml (can't be memoized)

  # dissertation id must be unique; D followed by 9 digits, e.g. D123456789
  let(:dissertation_id) { format('%10d', Kernel.rand(1..9_999_999_999)) }
  let(:random_title_words) { random_phrase }
  let(:dissertation_title) { "Integration Testing of ETD Processing - #{random_title_words}" }
  let(:random_author_word) { random_noun }
  let(:dissertation_author) { "Kelly, DeForest #{random_author_word}".capitalize }
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

  scenario do
    authenticate!(start_url: "#{Settings.etd_url}/view/0001",
                  expected_text: 'Could not find an Etd with id: 0001')

    # registrar creates ETD in hydra_etd application by posting xml
    resp_body = simulate_registrar_post(initial_xml_from_registrar)
    prefixed_druid = resp_body.split.first
    expect(prefixed_druid).to start_with('druid:')
    puts " *** ETD creation druid: #{prefixed_druid} ***" # useful for debugging
    puts " *** Dissertation id: #{dissertation_id} ***" # helpful for debugging

    visit "#{Settings.etd_url}/submit/#{dissertation_id}"

    # verify citation details
    expect(page).to have_css('li[aria-label="Step 1, Citation details verified, In progress"]')
    expect(page).to have_text(dissertation_id)
    expect(page).to have_text(dissertation_author)
    expect(page).to have_text(dissertation_title)
    find('button[aria-label="Confirm: Verify your citation details"]').click
    expect(page).to have_css('li[aria-label="Step 1, Citation details verified, Completed"]')

    # provide abstract
    expect(page).to have_css('li[aria-label="Step 2, Abstract provided, In progress"]')
    fill_in 'Abstract', with: abstract_text
    # Abstract is not persisted via auto-save until the blur event fires from the textarea element
    find('body').click
    find('button[aria-label="Done: Enter your abstract"]:not([disabled])').click
    expect(page).to have_css('li[aria-label="Step 2, Abstract provided, Completed"]')

    # confirm format has been reviewed
    expect(page).to have_css('li[aria-label="Step 3, Format reviewed, In progress"]')
    find('button[aria-label="Confirm: Review your dissertation\'s formatting before upload"]').click
    expect(page).to have_css('li[aria-label="Step 3, Format reviewed, Completed"]')

    # upload dissertation PDF
    expect(page).to have_css('li[aria-label="Step 4, Dissertation uploaded, In progress"]')
    attach_file('Upload PDF', "spec/fixtures/#{dissertation_filename}")
    find('button[aria-label="Done: Upload your dissertation"]').click
    expect(page).to have_css('li[aria-label="Step 4, Dissertation uploaded, Completed"]')

    # upload supplemental file
    expect(page).to have_css('li[aria-label="Step 5, Supplemental files uploaded, In progress"]')
    within('section[aria-label="5 Upload supplemental files in progress"]') do
      find('label', text: 'Yes').click
    end
    attach_file('Upload supplemental files', "spec/fixtures/#{supplemental_filename}")
    find('button[aria-label="Done: Upload supplemental files"]').click
    expect(page).to have_css('li[aria-label="Step 5, Supplemental files uploaded, Completed"]')

    # upload permission file
    expect(page).to have_css('li[aria-label="Step 6, Permission files uploaded, In progress"]')
    within('section[aria-label="6 Upload permissions in progress"]') do
      find('label', text: 'Yes').click
    end
    attach_file('Upload permission files', "spec/fixtures/#{permissions_filename}")
    find('button[aria-label="Done: Upload permissions"]').click
    expect(page).to have_css('li[aria-label="Step 6, Permission files uploaded, Completed"]')

    # apply licenses
    expect(page).to have_css('li[aria-label="Step 7, License terms applied, In progress"]')
    check 'I have read and agree to the terms of the Stanford University license'
    sleep 0.25 # wait for the checkbox form submit to be completed
    find('select[aria-label="Creative Commons license (required)"]').select('CC Attribution license')
    find('select[aria-label="Delayed release (required)"]').select('6 months')
    find('button[aria-label="Done: Apply copyright and license terms"]:not([disabled])').click
    expect(page).to have_css('li[aria-label="Step 7, License terms applied, Completed"]')

    click_button 'Review and submit'

    expect(page).to have_css('.h3', text: 'Review and submit')
    click_link_or_button 'Submit to Registrar'

    expect(page).to have_text('Submission successful')
    expect(page).to have_css('li[aria-label="Step 9, Verified by Final Reader, In progress"]')

    # fake reader approval
    # the faked reader approval time should be sufficiently past the submitted time to ensure it sticks
    now = (Time.now + 3600).in_time_zone('America/Los_Angeles').strftime('%m/%d/%Y %T')
    resp_body = simulate_registrar_post(reader_approval_xml_from_registrar)
    expect(resp_body).to eq "#{prefixed_druid} updated"
    page.refresh # needed to show updated progress box
    expect(page).to have_css('li[aria-label="Step 9, Verified by Final Reader, Completed"]')

    expect(page).to have_css('li[aria-label="Step 10, Approved by Registrar, In progress"]')

    # fake registrar approval
    now = (Time.now + 7200).in_time_zone('America/Los_Angeles').strftime('%m/%d/%Y %T')
    resp_body = simulate_registrar_post(registrar_approval_xml_from_registrar)
    expect(resp_body).to eq "#{prefixed_druid} updated"
    page.refresh # needed to show updated progress box
    expect(page).to have_css('li[aria-label="Step 10, Approved by Registrar, Completed"]')

    authenticate!(start_url: "#{Settings.argo_url}/view/#{prefixed_druid}",
                  expected_text: 'Embargoed until ')

    embargo_date = DateTime.now.utc.to_date >> 6
    embargo_date_plus1 = embargo_date + 1
    # now + 6 months is sometimes off by a day, maybe something timezone/utc/daylight savings related?
    embargo_date_regex_str = "[#{embargo_date.to_formatted_s(:long)}|#{embargo_date_plus1.to_formatted_s(:long)}]"
    reload_page_until_timeout!(text: /Embargoed until #{embargo_date_regex_str}/)
    expect(page).to have_text(dissertation_title)
    apo_element = find_table_cell_following(header_text: 'Admin policy')
    expect(apo_element.first('a')[:href]).to end_with('druid:bx911tp9024') # this is hardcoded in etd app
    status_element = find_table_cell_following(header_text: 'Status')
    expect(status_element).to have_text('v1 Registered')

    # test Embargo UI and indexing before an item is fully accessioned
    # check Argo facet field with 6 month embargo
    fill_in 'Search...', with: prefixed_druid
    click_button 'Search'
    click_link_or_button('Embargo Release Date')
    within '#facet-embargo_release_date ul.facet-values' do
      expect(page).to have_no_text('up to 7 days', wait: 1)
    end

    # Manage embargo
    new_embargo_date = Date.today + 3
    visit "#{Settings.argo_url}/view/#{prefixed_druid}"
    click_link_or_button 'Manage embargo'
    fill_in('Enter the date when this embargo ends', with: new_embargo_date.strftime('%F'))
    click_link_or_button 'Save'

    page.refresh # solves problem of update embargo modal re-appearing
    reload_page_until_timeout!(text: "Embargoed until #{new_embargo_date.to_formatted_s(:long)}")

    # check Argo facet field with 3 day embargo
    fill_in 'Search...', with: prefixed_druid
    click_button 'Search'
    click_link_or_button('Embargo Release Date')
    within '#facet-embargo_release_date ul.facet-values' do
      find_link('up to 7 days')
    end
  end
end

def simulate_registrar_post(xml)
  conn = Faraday.new(url: "#{Settings.etd_url}/etds") do |faraday|
    faraday.request :authorization, :basic, Settings.etd.username, Settings.etd.password
  end

  resp = conn.post do |req|
    req.options.timeout = 10
    req.options.open_timeout = 10
    req.headers['Content-Type'] = 'application/xml'
    req.body = xml
  end

  return resp.body if resp.success?

  raise "Error POSTing ETD: status #{resp.status}, #{resp.reason_phrase}, #{resp.body}"
end
