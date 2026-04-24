# frozen_string_literal: true

# Registers all of the expected objects for follow up tests
RSpec.describe 'Register objects in Argo', type: :registration do
  it_behaves_like 'an SDR object registion' do
    let(:spec_name) { 'access_indexing' }
  end

  it_behaves_like 'an SDR object registion' do
    let(:spec_name) { 'goobi_accessing' }
    let(:apo) { 'Goobi Testing APO' }
    let(:initial_workflow) { 'goobiWF' }
    let(:project) { 'Integration Testing' }
    let(:tags) { 'DPG : Workflow : Accession_Content_Expedited ' }
    let(:type) { 'image' }
  end

  it_behaves_like 'an SDR object registion' do
    let(:spec_name) { 'item_creation_no_files_or_collection' }
    let(:project) { 'Awesome Project' }
    let(:tags) { 'Some : UniqueTagValue' }
    let(:type) { 'book' }
    let(:collection) { 'None' }
  end

  it_behaves_like 'an SDR object registion' do
    let(:spec_name) { 'item_creation_with_folio_hrid' }
  end

  it_behaves_like 'an SDR object registion' do
    let(:spec_name) { 'preassembly_gis_raster_accessioning' }
  end

  it_behaves_like 'an SDR object registion' do
    let(:spec_name) { 'preassembly_gis_vector_accessioning' }
	end

	it_behaves_like 'an SDR object registion' do
    let(:spec_name) { 'preassembly_hfs_accessioning' }
	end

	it_behaves_like 'an SDR object registion' do
    let(:spec_name) { 'preassembly_ocr_document' }
	end

	it_behaves_like 'an SDR object registion' do
    let(:spec_name) { 'preassembly_ocr_image' }
	end

	it_behaves_like 'an SDR object registion' do
    let(:spec_name) { 'preassembly_gis_raster_accessioning' }
	end

	it_behaves_like 'an SDR object registion' do
    let(:spec_name) { 'preassembly_speech_to_text' }
	end

	it_behaves_like 'an SDR object registion' do
    let(:spec_name) { 'virtual_object_creation' }
	end
end
