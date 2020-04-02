# frozen_string_literal: true

# Preassembly requires files to be included in an object to be available on a mounted drive
# To this end, files have been placed on preassembly-stage at /dor/staging/integration-tests/media-test
# Note that media accessioning requires that directories be named for druids and filenames be prefixed by druid
# Note further that there must be (and are) associated md5 files present for every file in the media_manifest.csv
RSpec.describe 'Create new media objects via Pre-assembly', type: :feature do
  audio_druid, video_druid = '' # used for HEREDOC preassembly manifest files (can't be memoized)

  let(:start_url) { 'https://argo-stage.stanford.edu/items/register' }
  let(:preassembly_bundle_dir) { '/dor/staging/integration-tests/media-test' }
  let(:remote_manifest_location) { "preassembly@sul-preassembly-stage:#{preassembly_bundle_dir}" }
  let(:local_manifest_location) { 'tmp/manifest.csv' }
  let(:local_media_manifest_location) { 'tmp/media_manifest.csv' }
  let(:preassembly_project_name) { "IntegrationTest-media-#{RandomWord.nouns.next}" }
  let(:audio_source_id_random_word) { "#{RandomWord.adjs.next}-#{RandomWord.nouns.next}" }
  let(:audio_source_id) { "audio-integration-test:#{audio_source_id_random_word}" }
  let(:audio_label_random_words) { "#{RandomWord.adjs.next} #{RandomWord.nouns.next}" }
  let(:audio_object_label) { "audio integration test #{audio_label_random_words}" }
  let(:remote_audio_files_location) { "#{remote_manifest_location}/audio-object" }
  let(:audio_files) do
    [
      'audio_a_m4a.m4a',
      'audio_a_mp3.mp3',
      'audio_a_wav.wav',
      'audio_img_1.jpg',
      'audio_img_1.tif',
      'audio_pdf.pdf'
    ]
  end
  let(:video_source_id_random_word) { "#{RandomWord.adjs.next}-#{RandomWord.nouns.next}" }
  let(:video_source_id) { "video-integration-test:#{video_source_id_random_word}" }
  let(:video_label_random_words) { "#{RandomWord.adjs.next} #{RandomWord.nouns.next}" }
  let(:video_object_label) { "video integration test #{video_label_random_words}" }
  let(:remote_video_files_location) { "#{remote_manifest_location}/video-object" }
  let(:video_files) do
    [
      'video_1.mp4',
      'video_1.mpeg',
      'video_1_thumb.jp2',
      'video_2.mp4',
      'video_2.mpeg',
      'video_2_thumb.jp2',
      'video_img_1.tif',
      'video_img_2.tif',
      'video_log.txt'
    ]
  end
  let(:preassembly_manifest_csv) do
    <<~CSV
      druid,object
      #{audio_druid},#{audio_druid}
      #{video_druid},#{video_druid}
    CSV
  end
  let(:media_manifest_csv) do
    <<~CSV
      source_id,filename,label,sequence,publish,preserve,shelve,resource_type,thumb
      ,#{audio_druid}_#{audio_files[0]},Audio file 1,1,no,yes,no,audio,
      ,#{audio_druid}_#{audio_files[1]},Audio file 1,1,yes,yes,yes,audio,
      ,#{audio_druid}_#{audio_files[2]},Audio file 1,1,no,yes,no,audio,
      ,#{audio_druid}_#{audio_files[3]},Audio file 1,1,yes,yes,yes,image,thumb
      ,#{audio_druid}_#{audio_files[4]},Audio file 1,1,no,yes,no,image,
      ,#{audio_druid}_#{audio_files[5]},Transcript,2,yes,yes,yes,text,
      ,#{video_druid}_#{video_files[0]},Video file 1,1,yes,yes,yes,video,
      ,#{video_druid}_#{video_files[1]},Video file 1,1,no,yes,no,video,
      ,#{video_druid}_#{video_files[2]},Video file 1,1,yes,yes,yes,image,thumb
      ,#{video_druid}_#{video_files[3]},Video file 2,2,yes,yes,yes,video,
      ,#{video_druid}_#{video_files[4]},Video file 2,2,no,yes,no,video,
      ,#{video_druid}_#{video_files[5]},Video file 2,2,yes,yes,yes,image,thumb
      ,#{video_druid}_#{video_files[6]},Image of media (1 of 2),3,no,yes,no,image,
      ,#{video_druid}_#{video_files[7]},Image of media (2 of 2),4,no,yes,no,image,
      ,#{video_druid}_#{video_files[8]},Disc log file,5,no,yes,no,file,
    CSV
  end

  before do
    authenticate!(start_url: start_url,
                  expected_text: 'Register DOR Items')
  end

  it do
    # register both new objects (audio object and video object)
    select 'integration-testing', from: 'Admin Policy'
    select 'integration-testing', from: 'Collection'
    select 'Media', from: 'Content Type'
    fill_in 'Project Name', with: 'Integration Test - Audio'
    click_button 'Add Row'
    click_button 'Add Row'
    td_list = all('td.invalidDisplay')
    td_list[0].click
    fill_in '1_source_id', with: audio_source_id
    td_list[1].click
    fill_in '1_label', with: audio_object_label
    td_list[2].click
    fill_in '2_source_id', with: video_source_id
    td_list[3].click
    fill_in '2_label', with: video_object_label
    click_button('Lock')
    click_button('Register')

    # wait for objects to be registered
    Timeout.timeout(100) do
      loop do
        fill_in 'q', with: "#{audio_source_id_random_word} #{audio_label_random_words}"
        find_button('search').click
        break if page.has_text?(audio_object_label) && page.has_text?('v1 Registered')
      end
    end
    audio_druid = find('dd.blacklight-id').text.split(':').last
    # puts "audio druid: #{audio_druid}" # useful for debugging
    Timeout.timeout(100) do
      loop do
        fill_in 'q', with: "#{video_source_id_random_word} #{video_label_random_words}"
        find_button('search').click
        break if page.has_text?(video_object_label) && page.has_text?('v1 Registered')
      end
    end
    video_druid = find('dd.blacklight-id').text.split(':').last
    # puts "video druid: #{video_druid}" # useful for debugging

    # Set up preassembly staging directories and files with druid in the name,
    #   per media preassembly requirements
    remote_audio_files_dir = "#{remote_manifest_location}/#{audio_druid}"
    `scp -r #{remote_audio_files_location} #{remote_audio_files_dir}`
    raise("unable to scp #{remote_audio_files_location} to #{remote_audio_files_dir} - got #{$CHILD_STATUS.inspect}") unless $CHILD_STATUS.success?

    new_audio_files_dir = "#{preassembly_bundle_dir}/#{audio_druid}"
    command = "\"cd #{new_audio_files_dir}; for FNAME in *; do mv \"\\$FNAME\" #{audio_druid}_\"\\$FNAME\"; done\""
    `ssh preassembly@sul-preassembly-stage #{command}`
    raise("unable to mv #{new_audio_files_dir}/* to #{audio_druid}_* - got #{$CHILD_STATUS.inspect}") unless $CHILD_STATUS.success?

    remote_video_files_dir = "#{remote_manifest_location}/#{video_druid}"
    `scp -r #{remote_video_files_location} #{remote_video_files_dir}`
    raise("unable to scp #{remote_video_files_location} to #{remote_video_files_dir} - got #{$CHILD_STATUS.inspect}") unless $CHILD_STATUS.success?

    new_video_files_dir = "#{preassembly_bundle_dir}/#{video_druid}"
    command = "\"cd #{new_video_files_dir}; for FNAME in *; do mv \"\\$FNAME\" #{video_druid}_\"\\$FNAME\"; done\""
    `ssh preassembly@sul-preassembly-stage #{command}`
    raise("unable to mv #{new_video_files_dir}/* to #{video_druid}_* - got #{$CHILD_STATUS.inspect}") unless $CHILD_STATUS.success?

    # create manifest.csv file and scp it to preassembly staging directory
    File.write(local_manifest_location, preassembly_manifest_csv)
    `scp #{local_manifest_location} #{remote_manifest_location}`
    raise("unable to scp #{local_manifest_location} to #{remote_manifest_location} - got #{$CHILD_STATUS.inspect}") unless $CHILD_STATUS.success?

    # create media_manifest.csv and scp it to preassembly staging directory
    File.write(local_media_manifest_location, media_manifest_csv)
    `scp #{local_media_manifest_location} #{remote_manifest_location}`
    raise("unable to scp #{local_media_manifest_location} to #{remote_manifest_location} - got #{$CHILD_STATUS.inspect}") unless $CHILD_STATUS.success?

    visit 'https://sul-preassembly-stage.stanford.edu/'
    expect(page).to have_selector('h3', text: 'Complete the form below')

    fill_in 'Project name', with: preassembly_project_name
    select 'Pre Assembly Run', from: 'Job type'
    select 'Media', from: 'Content structure'
    fill_in 'Bundle dir', with: preassembly_bundle_dir
    select 'Media', from: 'Content metadata creation'

    click_button 'Submit'
    exp_str = 'Success! Your job is queued. A link to job output will be emailed to you upon completion.'
    expect(page).to have_content exp_str

    # go to job details page, download result
    first('td  > a').click
    expect(page).to have_content preassembly_project_name
    # wait for preassembly background job to finish
    Timeout.timeout(100) do
      loop do
        page.evaluate_script('window.location.reload()')
        break if page.has_link?('Download')
      end
    end
    click_link 'Download'
    wait_for_download
    yaml = YAML.load_file(download)
    expect(yaml[:status]).to eq 'success'

    # ensure audio object files are all there, per pre-assembly, organized into specified resources
    visit "https://argo-stage.stanford.edu/view/#{audio_druid}"
    expect(page).to have_selector('#document-contents-section > .resource-list > li.resource', text: 'Resource (1) audio')
    expect(page).to have_selector('#document-contents-section > .resource-list > li', text: 'Audio file 1')
    expect(page).to have_selector('#document-contents-section > .resource-list > li.resource', text: 'Resource (2) text')
    expect(page).to have_selector('#document-contents-section > .resource-list > li', text: 'Transcript')
    audio_files.each do |fname|
      expect(page).to have_text("#{audio_druid}_#{fname}")
    end

    # ensure video object files are all there, per pre-assembly, organized into specified resources
    visit "https://argo-stage.stanford.edu/view/#{video_druid}"
    expect(page).to have_selector('#document-contents-section > .resource-list > li.resource', text: 'Resource (1) video')
    expect(page).to have_selector('#document-contents-section > .resource-list > li', text: 'Video file 1')
    expect(page).to have_selector('#document-contents-section > .resource-list > li.resource', text: 'Resource (2) video')
    expect(page).to have_selector('#document-contents-section > .resource-list > li', text: 'Video file 2')
    expect(page).to have_selector('#document-contents-section > .resource-list > li.resource', text: 'Resource (3) image')
    expect(page).to have_selector('#document-contents-section > .resource-list > li', text: 'Image of media (1 of 2)')
    expect(page).to have_selector('#document-contents-section > .resource-list > li.resource', text: 'Resource (4) image')
    expect(page).to have_selector('#document-contents-section > .resource-list > li', text: 'Image of media (2 of 2)')
    expect(page).to have_selector('#document-contents-section > .resource-list > li.resource', text: 'Resource (5) file')
    expect(page).to have_selector('#document-contents-section > .resource-list > li', text: 'Disc log file')
    video_files.each do |fname|
      expect(page).to have_text("#{video_druid}_#{fname}")
    end

    # Wait for accessioningWF to finish for video object
    Timeout.timeout(100) do
      loop do
        page.evaluate_script('window.location.reload()')
        break if page.has_text?('v1 Accessioned')
      end
    end
    expect(page).to have_selector('.blacklight-content_type_ssim', text: 'media') # filled in by accessioning

    # Wait for accessioningWF to finish for audio object
    visit "https://argo-stage.stanford.edu/view/#{audio_druid}"
    Timeout.timeout(100) do
      loop do
        page.evaluate_script('window.location.reload()')
        break if page.has_text?('v1 Accessioned')
      end
    end
    expect(page).to have_selector('.blacklight-content_type_ssim', text: 'media') # filled in by accessioning
  end
end
