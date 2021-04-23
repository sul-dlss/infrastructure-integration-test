# frozen_string_literal: true

# NOTE: this can only be run on stage as there is no purl page for qa
module PurlHelpers
  # NOTE: for an embargo to appear on the purl page, the conditions are:
  #  (Fedora)
  #    - there must be contentMetadata
  #    - there must be rightsMetadata
  #    - there must be embargoMetadata
  #  (Cocina)
  #    - access data ... with the embargo in it as appropriate
  #    - access data correctly put in PURL xml
  #
  # ideally, would look for the following on purl page:
  #   "Access is restricted until #{embargo_date.strftime('%d-%b-%Y')}"
  # but this is in the embed *file* viewer only and it's within an iframe and I couldn't figure it out.

  def expect_embargo_date_in_purl(druid, embargo_date)
    Timeout.timeout(Settings.timeouts.publish) do
      loop do
        visit "#{Settings.purl_url}/#{druid}.xml"
        break if html.match?('rightsMetadata')

        sleep 1
      end
    end

    purl_ng_xml = Nokogiri::XML(html)
    embargo_nodes = purl_ng_xml.xpath('//rightsMetadata/access[@type="read"]/machine/embargoReleaseDate')
    expect(embargo_nodes.size).to eq 1
    expect(embargo_nodes.first.content).to eq embargo_date.strftime('%FT%TZ')
  end
end
