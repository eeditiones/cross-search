# cross-search

Prototype for an umbrella search over a number of Publisher apps

Apps used for the prototype:

* [Dodis](https://github.com/eeditiones/dodis-wall)
* [ELTeC](https://github.com/eeditiones/eltec)
* [Serafin](https://github.com/mikolajserafin/serafin7)

## Preliminary assumptions 

* Publisher 7 based apps

* comparable data sets; data can be encoded with any schema, but it should have the same (or at least mappable) fields and facets set defined and use the same taxonomies
* umbrella search endpoints, accepting the same set of parameters but differing in what units are returned:
  * document search: results are whole documents; corresponding to Publisher's metadata search
  * fragment search: results are document fragments: divisions/sections; corresponding to Publisher's full text search

*NB: we run out of time for the fragment search in the current iteration*

## Search

### Individual

Each of the apps to be aggregated in an umbrella search exposes the `/api/search/document` API endpoint:

It allows for a number of parameters, for the prototype assuming `title`, `author`, `lang(uage)` fields and `genre`, `language` and `corpus` facets. 
Each parameter corresponds to a field or facet definiton in the context of the app. Configuration of the mapping between `api/search/document` parameters and fields and facets of the app is realized via `config.xqm`: `$config:cross-search-facets` and `$config:cross-search-fields`.

Each field parameter has a corresponding `-operator` parameter representing a logical conjunction (AND / OR) to be used when querying for multiple base parameters (e.g. `author` and `author-operator`).

Parameters for use in facetted search follow the `facet-` naming pattern.

Additional `sort` parameter determines the order of sorting.

For a simple example, a request could specify parameters as follows to express a search for 
a document with a title containing the phrase 'new' and authored by someone with a name starting with B, containing the word 'street' anywhere in the document content:

* query: street
* author: b*, 
* title: new
* sort: author

It is assumed that individual apps implement the endpoints in a way, which returns matching results (representing documents) in a 
structure required for the aggregated search, namely:

* in a JSON format containing two parts
  * data array containing matched results as maps with 
    * app collection name
    * document path relative to the app data root colection
    * values for all the fields available for sorting
  * facets containing facet counts corresponding with the matched results

```json
{
  "data": [
    {
      "app": "dodis-facets",
      "filename": "52928.xml",
      "author": [
        "Plattner, Johann (1932–)",
        "Austria/Ministry of Foreign Affairs"
      ],
      "title": "Debatte über die deutsche Wiedervereinigung; Information und Sprachregelung",
      "language": "de"
    },
    ...
    ],
  "facets": {
    "genre": {
      "Telegram": 1,
      "Memo": 4
    },
    "corpus": {
      "Dodis": 5
    },
    "language": {
      "de": 5
    }
  }
}
```
    
Future, extended implementation might include also:

  * document fragment id (either xml:id or node-id) [optional]
  * full-text match ids [optional]
  * ODD-transformed document header [optional]
  * ODD-transformed full-text content matched [optional]

### Cross-search app

Umbrella app exposes the same API endpoint, but it only triggers the search through individual apps via http request and passes on the results.

Alternative approach would be that umbrella app actually runs the search through all relevant data collections at once but this would require that all apps reside in a single eXist instance and ideally share the fields and facets definitions (a mapping could be established to run tailored queries if not).

```xquery

declare variable $config:cross-search-facets := 
    map {
            "genre": "genre", 
            "language": "language-id",
            "corpus": "corpus"      
    };
declare variable $config:cross-search-fields := 
    map {
        "lang": "language-id", 
        "author":"author", 
        "title":"title"
    }; 
```
   
  