# frozen_string_literal: true

Dor::Services::Client.configure(url: Settings.dor_services.url,
                                token: Settings.dor_services.token)
