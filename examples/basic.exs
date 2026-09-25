client = WebsiteCategorizationAPI.Client.new(System.fetch_env!("AQ_API_KEY"))
IO.inspect(WebsiteCategorizationAPI.Client.classify(client, "https://example.com/article"))
