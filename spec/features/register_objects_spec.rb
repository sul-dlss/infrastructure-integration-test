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
    let(:project) { 'Awesome Folio Project' }
    let(:tags) { 'Some : UniqueTagValue' }
    let(:type) { 'book' }
    let(:folio_hrid) { Settings.test_folio_instance_hrid }
  end

  it_behaves_like 'an SDR object registion' do
    let(:spec_name) { 'preassembly_gis_raster_accessioning' }
    let(:project_name) { 'Integration Test - GIS via preassembly' }
    let(:collection) { 'Integration Test Collection - GIS' }
    let(:apo) { 'APO for GIS' }
    let(:type) { 'geo' }
  end

  it_behaves_like 'an SDR object registion' do
    let(:spec_name) { 'preassembly_gis_vector_accessioning' }
    let(:project_name) { 'Integration Test - GIS via preassembly' }
    let(:collection) { 'Integration Test Collection - GIS' }
    let(:apo) { 'APO for GIS' }
    let(:type) { 'geo' }
  end

  it_behaves_like 'an SDR object registion' do
    let(:spec_name) { 'preassembly_hfs_accessioning' }
    let(:project) { 'Integration Test - hierarchical files via Preassembly' }
    let(:type) { 'file' }
  end

  it_behaves_like 'an SDR object registion' do
    let(:spec_name) { 'preassembly_ocr_document' }
    let(:project) { 'Integration Test - Document OCR via Preassembly' }
    let(:type) { 'document' }
  end

  it_behaves_like 'an SDR object registion' do
    let(:spec_name) { 'preassembly_ocr_image' }
    let(:project) { 'Integration Test - Image OCR via Preassembly' }
    let(:type) { 'image' }
  end

  it_behaves_like 'an SDR object registion' do
    let(:spec_name) { 'preassembly_accessioning' }
    let(:project) { 'Integration Test - Accessioning via Preassembly' }
    let(:type) { 'image' }
  end

  it_behaves_like 'an SDR object registion' do
    let(:spec_name) { 'preassembly_speech_to_text' }
    let(:project) { 'Integration Test - Media Speech To Text via Preassembly' }
    let(:type) { 'media' }
  end

  context 'when registering virtual object constituents' do
    Settings.number_of_constituents.times do |i|
      it_behaves_like 'an SDR object registion' do
        let(:spec_name) { 'virtual_object_creation' }
        let(:project) { 'Integration Test - Virtual object via Preassembly' }
        let(:type) { 'image' }
        let(:virtual_source_id) { "virtual-object-creation:#{SecureRandom.uuid}-#{i}" }
      end
    end
  end
end
