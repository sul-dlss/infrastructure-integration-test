# frozen_string_literal: true

require 'rubyXL/convenience_methods/cell' # for rubyXL change_contents method

module XlsxHelpers
  def create_druid
    source_id = "spreadsheet-druid:#{RandomWord.phrases.next}"
    object_label = "Object Label for #{RandomWord.phrases.next}"
    # fill in registration form
    select 'integration-testing', from: 'Admin Policy'
    select 'integration-testing', from: 'Collection'
    click_button 'Add Row'
    td_list = all('td.invalidDisplay')
    td_list[0].click
    fill_in '1_source_id', with: source_id
    td_list[1].click
    fill_in '1_label', with: object_label
    find_field('1_label').send_keys :enter

    click_button('Register')
    # wait for object to be registered
    find('td[aria-describedby=data_status][title=success]')
    # Return new druid
    find('td[aria-describedby=data_druid]').text
  end

  def update_xlsx(druid1, title1, druid2, title2)
    temp_xlsx = Tempfile.new(['filled', '.xlsx'])
    filled_xlsx = RubyXL::Parser.parse('spec/fixtures/filled_template.xlsx')
    sheet_one = filled_xlsx.worksheets[0]
    sheet_one[2][0].change_contents druid1
    sheet_one[2][3].change_contents title1
    sheet_one[3][0].change_contents druid2
    sheet_one[3][3].change_contents title2
    filled_xlsx.write(temp_xlsx)
    temp_xlsx
  end
end
