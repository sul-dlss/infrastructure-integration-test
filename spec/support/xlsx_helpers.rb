# frozen_string_literal: true

require 'rubyXL/convenience_methods/cell' # for rubyXL change_contents method

module XlsxHelpers
  def create_druid
    source_id = "spreadsheet-druid:#{RandomWord.phrases.next}"
    object_label = "Object Label for #{RandomWord.phrases.next}"

    ensure_token
    deposit(
      apo: APO,
      source_id: source_id,
      label: object_label,
      collection: COLLECTION,
      url: API_URL
    )
  end

  def update_xlsx(druid1, title1, druid2, title2)
    temp_xlsx = Tempfile.new(['filled', '.xlsx'])
    filled_xlsx = RubyXL::Parser.parse('spec/fixtures/filled_template.xlsx')
    sheet_one = filled_xlsx.worksheets[0]
    sheet_one[2][0].change_contents druid1.delete_prefix('druid:')
    sheet_one[2][3].change_contents title1
    sheet_one[3][0].change_contents druid2.delete_prefix('druid:')
    sheet_one[3][3].change_contents title2
    filled_xlsx.write(temp_xlsx)
    temp_xlsx
  end
end
