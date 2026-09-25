# WebsiteCategorizationAPI

Elixir client to [check website category](https://www.websitecategorizationapi.com/website-url-category-check.php) data for any page. Give it a page URL and it returns the content categories of that page with confidence scores. Phoenix publishing sites, ad-tech services and analytics pipelines use those categories for contextual targeting, brand safety checks and topic reporting.

## Installation

```elixir
{:websitecategorizationapi, "~> 1.0"}
```

## A single page

```elixir
client = WebsiteCategorizationAPI.Client.new(System.fetch_env!("AQ_API_KEY"))

{:ok, %{"categories" => cats}} =
  WebsiteCategorizationAPI.Client.classify(client, "https://example.com/food/sourdough-starter-guide")

for c <- cats, do: IO.puts("tier #{c["tier"]}  #{c["name"]}  #{c["confidence"]}")
```

As the API reference describes, each category carries `"id"`, `"name"`, `"tier"` and `"confidence"`, and a `"meta"` map holds the request ID and processing time. Error details also appear in the body: a missing key, for instance, comes back with `"status" => 401` and an explanation.

## Categorise when an article is published

Topics belong to the article, not to each page view. In a Phoenix app, enqueue an Oban job when an article is published, and store the result on the record:

```elixir
defmodule MyBlog.Workers.Categorize do
  use Oban.Worker, queue: :categorize, max_attempts: 5

  @impl true
  def perform(%Oban.Job{args: %{"article_id" => id, "url" => url}}) do
    client = WebsiteCategorizationAPI.Client.new(Application.fetch_env!(:my_blog, :wca_key))

    case WebsiteCategorizationAPI.Client.classify(client, url) do
      {:ok, %{"categories" => cats} = body} when is_list(cats) ->
        MyBlog.Content.put_topics(id, body)

      {:error, {:api_error, 429, _}} ->
        {:snooze, 60}

      {:ok, body} ->
        {:error, {:unexpected_body, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
```

Call `MyBlog.Workers.Categorize.new(%{"article_id" => a.id, "url" => url}) |> Oban.insert()` from the publish action, and again only when the body text changes.

## Storing topics with Ecto

A `:map` field keeps the whole response for later analysis, and an array field holds the IDs you query on:

```elixir
schema "articles" do
  field :topics_raw, :map
  field :topic_ids, {:array, :string}, default: []
  field :topics_at, :utc_datetime
end
```

Keeping the raw body means a new report or threshold never needs another API call.

## Picking keys for the ad server

```elixir
def topic_keys(%{"categories" => cats}, floor \\ 0.5, max \\ 2) do
  cats
  |> Enum.filter(&(&1["confidence"] >= floor))
  |> Enum.sort_by(& &1["confidence"], :desc)
  |> Enum.take(max)
  |> Enum.map(&to_string(&1["id"]))
end
```

Render the result into the page's ad tag as key-values. Campaigns can then target the topic of the page instead of the history of the reader.

## Brand safety uses a different rule

For targeting, a moderate confidence floor is right. For brand safety, look at every returned category, including weak ones, and send borderline articles to an editor. Store the full body so the reviewer sees what the classifier saw.

## Tiers for reports

Report at tier 1 for a short, readable list of topics, at tier 2 for sales packages, and deeper only for brand safety lists. Since the whole response is stored, the same classification serves every depth.

## Thin pages

Photo galleries, video pages without transcripts and paywalled articles give the classifier little to read. When results look weak, classify the section page or the domain and apply that label to the thin pages below it.

## Reference

- `new(api_key, opts \\ [])`: `:base_url` is the only option, and the key must be a non-empty binary.
- `classify(client, value)`: posts `query`, `data_type=url` and the key as a form, and returns `{:ok, map}`, `{:error, {:api_error, status, body}}` or `{:error, exception}`.
- Requests use `Req.post/2`. POST requests are not retried automatically, so let Oban handle retries.

## Adjacent data

A topic taxonomy puts AI products under technology. [AI content filtering for the enterprise](https://www.aitoolsblocklist.com/enterprise-ai-blocking.php) keeps them apart by checking against the AI register. Compliance teams in regulated industries, where [shadow AI is a major compliance headache](https://www.shadowaitools.com/for-compliance-officers.php), collect evidence from network logs. For site-level labels at scale, [IAB 3.0 categories as a dataset](https://www.urlcategorizationdatabase.com/taxonomy.php) cost less than per-page classification.

Also available for [Go services](https://pkg.go.dev/github.com/explainableaixai/websitecategorizationapi-go), [Flutter apps](https://pub.dev/packages/websitecategorizationapi) and [PHP sites](https://packagist.org/packages/websitecategorization/websitecategorizationapi).

## License

MIT. IAB taxonomy names belong to IAB Technology Laboratory and appear for compatibility only.
