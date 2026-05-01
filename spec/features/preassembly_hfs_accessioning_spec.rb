# frozen_string_literal: true

require 'druid-tools'

# Integration: Argo, DSA, Preassembly, Purl
# Preassembly requires that files to be included in an object must be available on a mounted drive
# To this end, files have been placed on Settings.preassembly.host at Settings.preassembly.bundle_directory
RSpec.describe 'Create and re-accession object with hierarchical files via Pre-assembly', type: :preassembly do
  it_behaves_like 'preassembly job creation' do
    let(:spec_name) { 'preassembly_hfs_accessioning' }
    let(:object_label) { test_data[:title] }
    let(:expected_text) { object_label }
    let(:preassembly_bundle_dir) { Settings.preassembly.hfs_bundle_directory }
    let(:content_type) { 'File' }
    let(:navigate_to_job_details) { :click_first_link }
    let(:save_job_id) { true }
    let(:preassembly_manifest_csv) do
      <<~CSV
        druid,object
        #{druid},content
      CSV
    end

    after do
      # Additional verification after the shared example completes
      # ensure files are all there, per pre-assembly, organized into specified resources
      visit "#{Settings.argo_url}/view/#{druid}"

      # Wait for accessioningWF to finish
      reload_page_until_timeout!(text: /v\d+ Accessioned/)

      files = all('tr.file')

      # verify we have all of the files and that the paths match the incoming hierarchy
      expect(files.size).to eq 7
      expect(files[0].text).to match(%r{README.md text/plain 5.\d\d KB})
      expect(files[1].text).to match(%r{config/settings.yml text/plain 886 Bytes})
      expect(files[2].text).to match(%r{config/settings/qa.yml text/plain 900 Bytes})
      expect(files[3].text).to match(%r{config/settings/settings.yml text/plain 886 Bytes})
      expect(files[4].text).to match(%r{config/settings/staging.yml text/plain 905 Bytes})
      expect(files[5].text).to match(%r{images/image.jpg image/jpeg 28.\d KB})
      expect(files[6].text).to match(%r{images/subdir/image.jpg image/jpeg 28.\d KB})

      expect(find_table_cell_following(header_text: 'Content type').text).to eq('file') # filled in by accessioning

      # This section confirms the object has been published to PURL and has filenames in the json
      expect_text_on_purl_page(druid:, text: 'integration-testing')
      expect_text_on_purl_page(druid:, text: object_label)

      # verify the cocina json has the filenames with paths
      expect_published_files(druid:, filenames: ['README.md', 'config/settings.yml', 'config/settings/qa.yml',
                                                 'config/settings/settings.yml', 'config/settings/staging.yml'])
    end
  end
end
