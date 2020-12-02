# umbrella-search

Prototype for an umbrella search over a number of Publisher apps

Apps to be used for the prototype:

* [Dodis](https://github.com/eeditiones/dodis-wall)
* [ELTeC](https://github.com/eeditiones/eltec)
* other if time allows

## Preliminary assumptions 

* Publisher 7 based apps
* running on a single eXist-db instance

* comparable data sets; data can be encoded with any schema, but it should have the same (or at least mappable) fields and facets set defined and use the same taxonomies
* umbrella search endpoints, accepting the same set of parameters but differing in what units are returned:
  * document search: results are whole documents; corresponding to Publisher's metadata search
  * fragment search: results are document fragments: divisions/sections; corresponding to Publisher's full text search
 
## Search parameters

* full text query parameter(s) (e.g. search in entire text content, search in headings)
* metadata parameters (e.g. title, author, date, number)

## API endpoints


### Individual apps

Each of the apps to be aggregated in an umbrella search needs to expose 2 API endpoints:

* /api/search/document
* /api/search/fragment

Both endpoints allow for a number of parameters, for the prototype assuming title, author, language, id number and date. 
Each parameter ideally refers to a facet dimension and a field definiton in the context of the app. 
Each parameter accepts a pair: array of values and a logical conjunction (AND / OR).
Additional parameter to determine the order of sorting

For example, a request could specify parameters as follows to express a search for 
a document with a title containing the phrase 'TEI' and authored by Turska or Meier, containing the pattern 'compone*' anywhere in the document content:

* text: compone*
* author: [Turska, Meier], 'OR'
* title: *TEI*

It is assumed that individual apps implement the endpoints in a way, which returns matching results (representing documents or document fragments) in a structure required for the aggregated search, namely:

* in a JSON format containing
  * document id (and path relative to the data root)
  * document fragment id (either xml:id or node-id) [optional]
  * full-text match ids [optional]
  * values for all the fields available for sorting
  * ODD-transformed document header
  * ODD-transformed full-text content matched [optional]

### Umbrella app

Umbrella app exposes the same API endpoint, but these only trigger the search through individual apps and pass on the results.

Alternative approach would be that umbrella app actually runs the search through all relevant data collections at once but this would require that all apps share the fields and facets definitions.


   
  