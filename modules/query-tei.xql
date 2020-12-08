(:
 :
 :  Copyright (C) 2017 Wolfgang Meier
 :
 :  This program is free software: you can redistribute it and/or modify
 :  it under the terms of the GNU General Public License as published by
 :  the Free Software Foundation, either version 3 of the License, or
 :  (at your option) any later version.
 :
 :  This program is distributed in the hope that it will be useful,
 :  but WITHOUT ANY WARRANTY; without even the implied warranty of
 :  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 :  GNU General Public License for more details.
 :
 :  You should have received a copy of the GNU General Public License
 :  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 :)
xquery version "3.1";

module namespace teis="http://www.tei-c.org/tei-simple/query/tei";

declare namespace tei="http://www.tei-c.org/ns/1.0";

import module namespace config="http://www.tei-c.org/tei-simple/config" at "config.xqm";
import module namespace nav="http://www.tei-c.org/tei-simple/navigation/tei" at "navigation-tei.xql";
import module namespace query="http://www.tei-c.org/tei-simple/query" at "query.xql";
import module namespace http = "http://expath.org/ns/http-client";

declare function teis:query-default($fields as xs:string+, $query as xs:string, $target-texts as xs:string*,
    $sortBy as xs:string*) {
    if(string($query)) then
        for $field in $fields
        return
            switch ($field)
                case "head" return
                    if ($target-texts) then
                        for $text in $target-texts
                        return
                            $config:data-root ! doc(. || "/" || $text)//tei:head[ft:query(., $query, query:options($sortBy))]
                    else
                        collection($config:data-root)//tei:head[ft:query(., $query, query:options($sortBy))]
                default return
                    if ($target-texts) then
                        for $text in $target-texts
                        return
                            $config:data-root ! doc(. || "/" || $text)//tei:div[ft:query(., $query, query:options($sortBy))] |
                            $config:data-root ! doc(. || "/" || $text)//tei:text[ft:query(., $query, query:options($sortBy))]
                    else
                        collection($config:data-root)//tei:div[ft:query(., $query, query:options($sortBy))] |
                        collection($config:data-root)//tei:text[ft:query(., $query, query:options($sortBy))]
    else ()
};

declare function teis:query-metadata($field as xs:string, $query as xs:string, $sort as xs:string) {
    for $rootCol in $config:data-root
    for $doc in collection($rootCol)//tei:text[ft:query(., $field || ":(" || $query || ")", query:options($sort))]
    return
        $doc/ancestor::tei:TEI
};

declare function teis:autocomplete($doc as xs:string?, $fields as xs:string+, $q as xs:string) {
    for $field in $fields
    return
        switch ($field)
            case "author" return
                collection($config:data-root)/ft:index-keys-for-field("author", $q,
                    function($key, $count) {
                        $key
                    }, 30)
            case "file" return
                collection($config:data-root)/ft:index-keys-for-field("file", $q,
                    function($key, $count) {
                        $key
                    }, 30)
            case "text" return
                if ($doc) then (
                    doc($config:data-root || "/" || $doc)/util:index-keys-by-qname(xs:QName("tei:div"), $q,
                        function($key, $count) {
                            $key
                        }, 30, "lucene-index"),
                    doc($config:data-root || "/" || $doc)/util:index-keys-by-qname(xs:QName("tei:text"), $q,
                        function($key, $count) {
                            $key
                        }, 30, "lucene-index")
                ) else (
                    collection($config:data-root)/util:index-keys-by-qname(xs:QName("tei:div"), $q,
                        function($key, $count) {
                            $key
                        }, 30, "lucene-index"),
                    collection($config:data-root)/util:index-keys-by-qname(xs:QName("tei:text"), $q,
                        function($key, $count) {
                            $key
                        }, 30, "lucene-index")
                )
            case "head" return
                if ($doc) then
                    doc($config:data-root || "/" || $doc)/util:index-keys-by-qname(xs:QName("tei:head"), $q,
                        function($key, $count) {
                            $key
                        }, 30, "lucene-index")
                else
                    collection($config:data-root)/util:index-keys-by-qname(xs:QName("tei:head"), $q,
                        function($key, $count) {
                            $key
                        }, 30, "lucene-index")
            default return
                collection($config:data-root)/ft:index-keys-for-field("title", $q,
                    function($key, $count) {
                        $key
                    }, 30)
};

declare function teis:get-parent-section($node as node()) {
    ($node/self::tei:text, $node/ancestor-or-self::tei:div[1], $node)[1]
};

declare function teis:get-breadcrumbs($config as map(*), $hit as node(), $parent-id as xs:string) {
    let $work := root($hit)/*
    let $work-title := nav:get-document-title($config, $work)/string()
    return
        <div class="breadcrumbs">
            <a class="breadcrumb" href="{$parent-id}">{$work-title}</a>
            {
                for $parentDiv in $hit/ancestor-or-self::tei:div[tei:head]
                let $id := util:node-id(
                    if ($config?view = "page") then ($parentDiv/preceding::tei:pb[1], $parentDiv)[1] else $parentDiv
                )
                return
                    <a class="breadcrumb" href="{$parent-id || "?action=search&amp;root=" || $id || "&amp;view=" || $config?view || "&amp;odd=" || $config?odd}">
                    {$parentDiv/tei:head/string()}
                    </a>
            }
        </div>
};

(:~
 : Expand the given element and highlight query matches by re-running the query
 : on it.
 :)
declare function teis:expand($data as node()) {
    let $query := session:get-attribute($config:session-prefix || ".query")
    let $field := session:get-attribute($config:session-prefix || ".field")
    let $div :=
        if ($data instance of element(tei:pb)) then
            let $nextPage := $data/following::tei:pb[1]
            return
                if ($nextPage) then
                    if ($field = "text") then
                        (
                            ($data/ancestor::tei:div intersect $nextPage/ancestor::tei:div)[last()],
                            $data/ancestor::tei:text
                        )[1]
                    else
                        $data/ancestor::tei:text
                else
                    (: if there's only one pb in the document, it's whole
                      text part should be returned :)
                    if (count($data/ancestor::tei:text//tei:pb) = 1) then
                        ($data/ancestor::tei:text)
                    else
                      ($data/ancestor::tei:div, $data/ancestor::tei:text)[1]
        else
            $data
    let $result := teis:query-default-view($div, $query, $field)
    let $expanded :=
        if (exists($result)) then
            util:expand($result, "add-exist-id=all")
        else
            $div
    return
        if ($data instance of element(tei:pb)) then
            $expanded//tei:pb[@exist:id = util:node-id($data)]
        else
            $expanded
};


declare %private function teis:query-default-view($context as element()*, $query as xs:string, $fields as xs:string+) {
    for $field in $fields
    return
        switch ($field)
            case "head" return
                $context[./descendant-or-self::tei:head[ft:query(., $query, $query:QUERY_OPTIONS)]]
            default return
                $context[./descendant-or-self::tei:div[ft:query(., $query, $query:QUERY_OPTIONS)]] |
                $context[./descendant-or-self::tei:text[ft:query(., $query, $query:QUERY_OPTIONS)]]
};

declare function teis:get-current($config as map(*), $div as node()?) {
    if (empty($div)) then
        ()
    else
        if ($div instance of element(tei:teiHeader)) then
            $div
        else
            (nav:filler($config, $div), $div)[1]
};

declare function teis:query-document($request as map(*)) {
    let $params := $request?parameters
    let $q := string-join(
        for $p in map:keys($params)
            return 
                if($params($p)) then 
                        for $entry in $params($p) return
                        $p || '=' ||$entry
                else
                    ()
        , '&amp;')


    let $summary := string-join(
        for $p in map:keys($params)
            return 
                if($params($p)) then 
                        for $entry in $params($p) 
                        return
                            if (not(ends-with($p, '-operator'))) then
                                $p || ':' ||$entry
                            else
                                ()
                else
                    ()
        , ', ')

    let $data :=
        for $app in $config:sub?app
            let $request := 
                <http:request method="GET" 
                href="{$config:server}/{$app}/api/search/document?{$q}"/>
                                
            return parse-json(util:base64-decode(http:send-request($request)[2]))

    (: Set facets and results, checking if there are actual matches returned and not just empty arrays  :)
    let $facets := for $edition in $data return 
        if ($edition?data(1) instance of map(*)) then $edition?facets else ()
    let $results := for $edition in $data return 
        if ($edition?data(1) instance of map(*) ) then $edition?data else ()

    (: recombine returned results into a single map :)
    let $entries :=  
        for $edition in $results
            for $i in 1 to array:size($edition)
                return $edition($i)
               
    let $hitCount := count($entries)

    return 
        <div class="results">
            <paper-card class="facets" data-i18n="[heading]umbrella.panels.facets">
                {teis:display-facets($facets)}
            </paper-card>  
            <paper-card class="matches" data-i18n="[heading]umbrella.panels.results">
                <div class="card-content">
                    <h3><pb-i18n key="umbrella.query">Query:</pb-i18n> {$summary}</h3>
                    <h4><pb-i18n key="umbrella.matches">Matches:</pb-i18n> { $hitCount }</h4>
                </div>
                {teis:display(teis:sort($entries, $request?parameters?sort))}
            </paper-card>
        </div>
};

declare function teis:sort($entries, $sort) {
    for $i in $entries
        let $s:= $i($sort)
        (: make sure that only a single atomic value is used for sorting :)
        let $first := if ($s instance of array(*)) then array:head($s) else $s
        order by $first

    return $i
};
declare function teis:display($entries) {
    for $entry in $entries
    
    return 
        <paper-card>
            <h3><a href="{$config:server}/{$entry?app}/{$entry?filename}" target="_blank">{$entry?title}</a></h3>
            <h4>{$entry?author}</h4>
        </paper-card>
};


declare function teis:display-facets($editions) {

    let $facet-dimensions:= 
        for $config in $config:facets?*
            return $config?dimension

    (: Aggregate facet data from editions :)
    let $facets:= 
    map:merge((
        for $dimension in $facet-dimensions

        return map {
            $dimension:
            map:merge(
            for $edition in $editions
                return
                    $edition($dimension)
            )
        }
    ))      

    return 
        <pb-custom-form id="facets" emit="search" subscribe="search">
            { teis:facets-form($facets) }
        </pb-custom-form>
};


declare function teis:facets-form($facets) {
    for $config in $config:facets?*      
        let $params := request:get-parameter("facet-" || $config?dimension, ())

    return
            for $dimension in $config?dimension
                for $d in $facets($dimension)

                return
                    teis:dimension-card($dimension, $d, $config, $params)              
};

declare function teis:dimension-card($dimension, $facets, $config, $values) {
    <paper-card>
        <h3><pb-i18n key="{$config?heading}">{$config?heading}</pb-i18n></h3>
            <table>
            {for $label in map:keys($facets)
                return 
                <tr>
                    <td>
                        <paper-checkbox class="facet" name="facet-{$dimension}" value="{$label}">
                            { if ($label = $values) then attribute checked { "checked" } else () }
                            {
                                if (exists($config?output)) then
                                    $config?output($label)
                                else
                                    $label
                            }
                            
                        </paper-checkbox>
                    </td>
                    <td>
                        {$facets($label)}
                    </td>
                </tr>
            }
            </table>
    </paper-card>
};

declare function teis:query-apps-available($request as map(*)) {
    for $app in $config:sub 
        return     

        <div class="tiles">
            <div class="round">
                <a href="../{$app?app}/index.html"  data-template="pages:parse-params"
                    title="{$app?title}" target="_blank">
                        <img alt="{$app?title}" src="../{$app?app}/resources/images/{$app?icon}" data-template="pages:parse-params"/>
                </a>
            </div>
            <h3>{$app?title}</h3>
        </div>
};

declare function teis:facets($request as map(*)) {

    let $facets:=
        for $app in $config:sub?app
                let $request := 
                    <http:request method="GET" 
                    href="{$config:server}/{$app}/api/search/facets"/>
                    
                let $return:= parse-json(util:base64-decode(http:send-request($request)[2]))
                return $return
    
    return $facets
};