# frozen_string_literal: true

# Integration: Argo, DSA, Preassembly, Purl
# Preassembly requires that files to be included in an object must be available on a mounted drive
# To this end, files have been placed on Settings.preassembly.host at Settings.preassembly.bundle_directory
# # This uses the preassembly_job_creation shared example.
RSpec.describe 'Create a Pre-assembly job', :sample_accession, type: :accessioning do
  it_behaves_like 'preassembly job creation' do
    let(:spec_name) { 'preassembly_accessioning' }
  end
end
