# frozen_string_literal: true

require 'dor/services/client'

module PurlHelpers
  # NOTE: for an embargo to appear on the purl page, the conditions are:
  #  (Fedora)
  #    - there must be contentMetadata
  #    - there must be rightsMetadata
  #    - there must be embargoMetadata
  #  (Cocina)
  #    - access data ... with the embargo in it as appropriate
  #    - access data correctly put in PURL xml
  def expect_embargo_date_in_purl(druid, embargo_date)
    Dor::Services::Client.configure(url: Settings.dor_services.url, token: Settings.dor_services.token)
    xml = Dor::Services::Client.object("druid:#{druid}").metadata.public_xml
    purl_ng_xml = Nokogiri::XML(xml)
    embargo_nodes = purl_ng_xml.xpath('//rightsMetadata/access[@type="read"]/machine/embargoReleaseDate')
    expect(embargo_nodes.size).to eq 1
    expect(embargo_nodes.first.content).to eq embargo_date.strftime('%FT%TZ')
  end
end
