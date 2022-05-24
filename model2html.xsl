<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns="http://www.w3.org/1999/xhtml"
    xmlns:html="http://www.w3.org/1999/xhtml"
    xmlns:_="urn:local"
    exclude-result-prefixes="#all"
    version="2.0">  
    <xsl:param name="debug">false</xsl:param>
    <xsl:param name="pathToGraphImage"/>
    <xsl:variable name="doc" select="root(.)"/>
    <xsl:output method="xhtml" indent="yes" include-content-type="yes"/>
    <xsl:strip-space elements="*"/>
    <xsl:preserve-space elements="p note item path"/>
    <xsl:function name="_:head">
        <xsl:param name="item" as="item()*"/>
        <xsl:param name="text"/>
<!--        <xsl:variable name="hl" select="if ($item instance of xs:integer) then $item else count($item/ancestor::*[self::classes|self::class|self::model|self::property|self::relation|self::groups])"/>-->
        <xsl:variable name="hl" select="if ($item instance of xs:integer) then $item else count($item/ancestor-or-self::*)"/>
        <xsl:element name="h{$hl}">
            <xsl:attribute name="class">title is-<xsl:value-of select="$hl"/></xsl:attribute>
            <xsl:value-of select="$text"/>
        </xsl:element>
    </xsl:function>
    
    
    <xsl:function name="_:entityByID" as="element()*">
        <xsl:param name="entityID"/>
        <xsl:call-template name="entityByID">
            <xsl:with-param name="entityID" select="$entityID"/>
        </xsl:call-template>
    </xsl:function>
    
    <xsl:function name="_:entityByName" as="element(*)*">
        <xsl:param name="entityName"/>
        <xsl:variable name="entity" select="$doc//name[lower-case(.)=lower-case($entityName)]/.."/>
        <xsl:sequence select="$entity"/>
    </xsl:function>

    <xsl:function name="_:ancestorsByID">
        <!-- the ID of the subclass -->
        <xsl:param name="classID"/>
        <xsl:variable name="classDef">
            <xsl:call-template name="entityByID">
                <xsl:with-param name="entityID" select="$classID"/>
            </xsl:call-template>
        </xsl:variable>
        <xsl:if test="$classDef/@parent != ''">
            <xsl:sequence select="_:entityByID($classDef/@parent)"/>
            <xsl:sequence select="_:ancestorsByID($classDef/@parent)"/>
        </xsl:if>
    </xsl:function>

    <xsl:function name="_:head">
        <xsl:param name="item" as="item()*"/>
        <xsl:sequence select="_:head($item, data($item))"/>
    </xsl:function>
   
    <xsl:template match="/">
        <xsl:message>$debug = <xsl:value-of select="$debug"/></xsl:message>
        <xsl:if test="$debug = 'true'">
            <xsl:message>$pathToGraphImage = <xsl:value-of select="$pathToGraphImage"/></xsl:message>
        </xsl:if>
        <html>
            <head>
                <meta charset="utf-8"></meta>
                <title><xsl:value-of select="/model/meta/title"/></title>
                <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bulma@0.9.3/css/bulma.min.css">&#160;</link>
                <script src="https://cdn.jsdelivr.net/npm/svg-pan-zoom/dist/svg-pan-zoom.min.js"/>
                <meta name="viewport" content="width=device-width, initial-scale=1"></meta>
            </head>
            <body>  
                <div class="container">
                    <section class="section">
                        <h1 class="title is-1"><xsl:value-of select="/model/meta/title"/></h1>
                        <h2 class="subtitle is-3">Version <xsl:value-of select="/model/meta/version"/></h2>
                        <header class="header">
                            <table class="table is-hoverable is-narrow">
                                <tr class="tr">
                                    <td>Author(s): </td>
                                    <td><xsl:value-of select="string-join(//contributor[@role = 'author']/person/name,'&#160;')"/></td>
                                </tr>
                                <tr>
                                    <td>Version: </td>
                                    <td><xsl:value-of select="//version"/></td>
                                </tr>
                                <tr>
                                    <td>Last Changed: </td>
                                    <td><xsl:value-of select="max(//change/xs:date(@when))"/></td>
                                </tr>
                                <tr>
                                    <td>Documentation generated: </td>
                                    <td><xsl:value-of select="current-dateTime()"/></td>
                                </tr>
                                <xsl:for-each select="//docProp">
                                    <tr><td><xsl:value-of select="@name"/></td>
                                        <td><xsl:apply-templates/></td></tr>
                                </xsl:for-each>
                            </table>
                        </header>
                    </section>
                    <section class="section">
                        <h2 class="title">Graphical Overview</h2>
                        <figure class="image" style="max-width: 100%; overflow: hidden; position: relative; border: 1px solid gray;">
                            <xsl:choose>
                                <xsl:when test="ends-with($pathToGraphImage,'svg')">
                                    <xsl:sequence select="doc($pathToGraphImage)"/>
                                </xsl:when>
                                <xsl:otherwise>
                                    <img src="{$pathToGraphImage}" class="img-responsive img-fit-contain"/>
                                </xsl:otherwise>
                            </xsl:choose>
                            <figcaption class="figure-caption text-center">Graphical Overview of the data model.<br/>Dashed lines mean implicit shortcut relations.</figcaption>
                        </figure>
                    </section>
                    <xsl:apply-templates/>
                    <xsl:if test="not(exists(model/relations))">
                        <div class="content">
                            <xsl:sequence select="_:head(2, 'Relations')"/>
                            <xsl:apply-templates select="//relation" mode="mkPar"/>
                        </div>
                    </xsl:if>
                </div>
                <script><![CDATA[
                    window.onload = function() {
                        var svgElement = document.querySelector('svg')
                        var panZoomGraph = svgPanZoom(svgElement, {
                            zoomEnabled: true,
                            controlIconsEnabled: true
                        })
                    };
                ]]></script>
            </body>
        </html>
    </xsl:template>

    <xsl:template match="head">
        <xsl:sequence select="_:head(.)"/>
    </xsl:template>
    
    <xsl:template match="meta/changelog">
        <table class="table">
            <xsl:apply-templates/>
        </table>
    </xsl:template>
    
    <xsl:template match="change">
        <tr>
            <td><xsl:value-of select="@when"/></td>
            <td><xsl:value-of select="@who"/></td>
            <td><xsl:value-of select="@status"/></td>
            <td><xsl:apply-templates/></td>
        </tr>
    </xsl:template>
    
    <xsl:template match="meta"/>
    
    <xsl:template match="model/*" priority="-1">
        <xsl:variable name="head" select="concat(upper-case(substring(local-name(.),1,1)),substring(local-name(.),2))"/>
        <xsl:sequence select="_:head(.,$head)"/>
        <xsl:apply-templates/>
    </xsl:template>

    <xsl:template match="model/description|model/relations">
        <xsl:variable name="head" select="concat(upper-case(substring(local-name(.),1,1)),substring(local-name(.),2))"/>
        <h2 class="title is-2"><xsl:value-of select="$head"/></h2>
        <div class="content">
            <xsl:choose>
                <xsl:when test="self::relations">
                    <xsl:apply-templates mode="mkPar"/>
                    <xsl:apply-templates select="$doc//class//relation" mode="mkPar"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:apply-templates/>
                </xsl:otherwise>
            </xsl:choose>
        </div>
    </xsl:template>
    
    <xsl:template match="class/relations"/>
        
    
    <xsl:template match="class/definition|class/examples|class/properties|model/vocabularies|model/datatypes">
        <xsl:variable name="head" select="concat(upper-case(substring(local-name(.),1,1)),substring(local-name(.),2))"/>
        <xsl:if test="node()">
            <div class="{if (parent::model) then 'section' else 'content'}">
                <xsl:choose>
                    <xsl:when test="self::vocabularies or self::datatypes">
                        <xsl:sequence select="_:head(., $head)"/>
                        <xsl:apply-templates select="." mode="mkTable"/>
                    </xsl:when>
                    <xsl:when test="self::relations">
                        <xsl:sequence select="_:head(., $head)"/>
                        <xsl:apply-templates select="." mode="mkPar"/>
                    </xsl:when>
                    <xsl:when test="self::properties ">
                        <xsl:sequence select="_:head(., $head)"/>
                        <xsl:apply-templates select="." mode="mkTable"/>
                    </xsl:when>
                    <!-- moving to a template producing a "info box" -->
                    <!--<xsl:when test="self::note[parent::class]">
                        <xsl:sequence select="_:head(., 'Remarks on this class')"/>
                        <xsl:apply-templates/>
                    </xsl:when>-->
                    <xsl:otherwise>
                        <xsl:sequence select="_:head(., $head)"/>
                        <xsl:apply-templates/>
                    </xsl:otherwise>
                </xsl:choose>
            </div>
        </xsl:if>
    </xsl:template>
    
    <xsl:template match="note" mode="inCell">
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="CHECKME|TODO|note">
        <xsl:variable name="tag-color">
            <xsl:choose>
                <xsl:when test="local-name(.) = 'CHECKME'">is-danger</xsl:when>
                <xsl:when test="self::note[parent::class]">is-info</xsl:when>
                <xsl:otherwise>is-warning</xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <div class="box">
            <span class="tag {$tag-color} is-light"><xsl:value-of select="upper-case(local-name())"/></span>&#160;<xsl:apply-templates/>
            <p class="is-size-7 has-text-right has-text-weight-light"><xsl:for-each select="@*"><xsl:value-of select="concat(local-name(),': ', .,'&#160;')"/></xsl:for-each></p>
        </div>
    </xsl:template>
    
    <xsl:template match="reference">
        <blockquote><xsl:apply-templates/></blockquote>
    </xsl:template>
    
    <xsl:template match="class/examples/example">
        <xsl:call-template name="mkExample"/>
    </xsl:template>
    
    <xsl:template match="mapping">
        <xsl:sequence select="_:head(.,concat('Mapping to ',$doc//reference[@ID = current()/@targetLanguage]//name))"/>
        <p class="content">
            <xsl:apply-templates select="@* except @targetLanguage"/>
        </p>
        <p class="block"><xsl:apply-templates select="node()"/></p>
    </xsl:template>
    <xsl:template match="mapping/@targetLanguage"/>
        
    <xsl:template match="mapping/@level">
        <span class="strong">Mapping Level:</span> <xsl:value-of select="."/><br/>
    </xsl:template>
    <xsl:template match="mapping/@version">
        <span class="strong">Version: </span><xsl:value-of select="."/><br/>
    </xsl:template>
    <!--<xsl:template match="note[not(*)]">
        <p>NB: <xsl:apply-templates/></p>
    </xsl:template>
    <xsl:template match="mapping/note[*]">
        NB: <xsl:apply-templates/>
    </xsl:template>-->
    
    <xsl:template match="mapping/code|example/code">
        <!-- WATCHME do not remove data-type="listing" here because it will be used 
            by the builder script for code-highlighting -->
        <pre style="border: 1px solid black;">
            <code data-type="listing">
                <xsl:sequence select="node()"/>
            </code>
        </pre>
    </xsl:template>
    
    
    
    <xsl:template name="classDependencies">
        <xsl:if test="@parent != ''">
            <xsl:variable name="parentClassDef" select="_:entityByID(@parent)"/>
            <xsl:variable name="parentClassLink" as="element()">
                <className xmlns="" target="{@parent}"><xsl:value-of select="$parentClassDef/name"/></className>
            </xsl:variable>
            <p class="block"><strong>Subclass of: </strong><xsl:apply-templates select="$parentClassLink"/></p>
            <!--<xsl:apply-templates select="_:ancestorsByID(@parent)//properties"/>-->
        </xsl:if>
        <xsl:if test="exists(root()//*[@parent = current()/@ID])">
            <xsl:variable name="subClassID" select="root()//*[@parent = current()/@ID]/@ID"/>
            <xsl:variable name="subClassLink" as="element()*">
                <xsl:for-each select="$subClassID">
                    <xsl:variable name="subClassDef" select="_:entityByID(.)"/>
                    <className xmlns="" target="{.}"><xsl:value-of select="$subClassDef/name"/></className>
                </xsl:for-each>
            </xsl:variable>
            <p class="block"><strong>Superclass of: </strong>
                <xsl:for-each select="$subClassLink">
                    <xsl:apply-templates select="."/>
                    <xsl:if test="position() lt count($subClassLink)">, </xsl:if>
                </xsl:for-each>
            </p>
        </xsl:if>
    </xsl:template>
    
    <xsl:template match="class">
        <div class="section">
            <a id="{@ID}"/>
            <xsl:apply-templates select="name"/>
            <xsl:call-template name="classDependencies"/>
            <xsl:apply-templates select="* except (name|relations)"/>
            <xsl:variable name="relsOut">
                <xsl:call-template name="filterRelations">
                    <xsl:with-param name="classID" select="@ID"/>
                    <xsl:with-param name="direction" select="'outgoing'"/>
                    <xsl:with-param name="includeInherited" select="true()"/>
                </xsl:call-template>
            </xsl:variable>
            
            <div class="content">
                <xsl:sequence select="_:head(4, 'Relations (outgoing)')"/>
                <xsl:choose>
                    <xsl:when test="not($relsOut//html:li)">
                        <p>No outgoing relations defined.</p>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:sequence select="$relsOut"/>
                    </xsl:otherwise>
                </xsl:choose>
            </div>
                        
            <xsl:variable name="relsIn">
                <xsl:call-template name="filterRelations">
                    <xsl:with-param name="classID" select="@ID"/>
                    <xsl:with-param name="direction" select="'incoming'"/>
                    <xsl:with-param name="includeInherited" select="true()"/>
                </xsl:call-template>
            </xsl:variable>
            

            <div class="content">
                <xsl:sequence select="_:head(4, 'Relations (incoming)')"/>
                <xsl:choose>
                    <xsl:when test="not($relsIn//html:li)">
                        <p>No outgoing relations defined.</p>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:sequence select="$relsIn"/>
                    </xsl:otherwise>
                </xsl:choose>
            </div>
        </div>
    </xsl:template>
    
    <xsl:template name="filterRelations">
        <xsl:param name="classID" as="attribute(ID)+"/>
        <xsl:param name="direction"/>
        <xsl:param name="includeInherited" as="xs:boolean"/>
        <xsl:variable name="inheritedRelations" as="element(relation)*">
            <xsl:if test="$includeInherited">
                <xsl:variable name="classDef">
                    <xsl:call-template name="entityByID">
                        <xsl:with-param name="entityID" select="$classID"/>
                    </xsl:call-template>
                </xsl:variable>
                <xsl:variable name="parent" select="$classDef/@parent"/>
                <xsl:if test="$parent != ''">
                    <xsl:call-template name="filterRelations">
                        <xsl:with-param name="classID" select="$parent"/>
                        <xsl:with-param name="direction" select="$direction"/>
                        <xsl:with-param name="includeInherited" select="true()"/>
                    </xsl:call-template>
                </xsl:if>
            </xsl:if>
        </xsl:variable>
        <xsl:variable name="relations" as="element(relation)*">
            <xsl:for-each select="(root()//relation[if ($direction = 'incoming') then targetClass/@target = $classID else sourceClass/@target = $classID],$inheritedRelations)">
                <xsl:sort select="name"/>
                <xsl:sequence select="."/>
            </xsl:for-each>
        </xsl:variable>
        <xsl:message select="$classID||' '||$direction||' '||count($relations)"/>
        <xsl:call-template name="mkRelationsList">
            <xsl:with-param name="relations" select="$relations"/>
            <xsl:with-param name="duplicate" select="true()" as="xs:boolean" tunnel="yes"/>
        </xsl:call-template>
    </xsl:template>
    
    
    <xsl:template match="class/name">
        <xsl:sequence select="_:head(.., concat('Class: &quot;',.,'&quot;'))"/>
    </xsl:template>
    
    <xsl:template match="properties" mode="mkTable">
        <table class="table table-ho">
            <thead>
                <tr>
                    <th>Property Name / Cardinality</th>
                    <th>Data Type</th>
                    <th>Remarks</th>
                </tr>
            </thead>
            <xsl:apply-templates mode="#current">
                <xsl:sort select="name"/>
            </xsl:apply-templates>
        </table>
    </xsl:template>
    
    <xsl:template match="property" mode="mkTable">
        <tr>
            <td>
                <a id="{@ID}"/><b><xsl:value-of select="name"/></b><br/>
                <xsl:text>Cardinality: </xsl:text><xsl:value-of select="arity"/> 
            </td>
            <td><xsl:apply-templates select="datatypeName"/></td>
            <td><xsl:apply-templates select="note" mode="inCell"/>
                <xsl:apply-templates select="internalStructure" mode="inCell"/></td>
        </tr>
    </xsl:template>
    
    <xsl:template match="internalStructure" mode="inCell">
        <p>
            <xsl:value-of select="@type"/><xsl:text>:</xsl:text><br/>
            <xsl:apply-templates mode="mkList"/>
        </p>
    </xsl:template>
    
    <xsl:template match="properties" mode="mkList">
        <ul>
            <xsl:apply-templates mode="#current"/>
        </ul>
    </xsl:template>
    
    <xsl:template match="property" mode="mkList">
        <li>
            <a id="{@ID}"/>
            <xsl:value-of select="arity/concat(.,' ')"/>
            <b><xsl:value-of select="name"/>: </b>
            <xsl:apply-templates select="note|CHECKME|TODO"/>
            <xsl:text>Datatype: </xsl:text>
            <a href="#{datatypeName/@target}"><xsl:value-of select="_:entityByID(datatypeName/@target)/name/concat(.,' ')"/></a>
            <xsl:if test="@vocabRef!=''">
                <xsl:text> in </xsl:text>
                <a href="#{datatypeName/@vocabRef}"><xsl:value-of select="_:entityByID(datatypeName/@vocabRef)/name/concat(.,' ')"/></a>
            </xsl:if>
        </li>
    </xsl:template>
    
    <xsl:template match="properties" mode="mkPar">
        <xsl:apply-templates mode="#current">
            <xsl:sort select="name"/>
        </xsl:apply-templates>
    </xsl:template>
    
    <xsl:template match="property" mode="mkPar">
        <div class="property">
            <p class="title is-6"><a id="{@ID}"/>Property: <b><xsl:value-of select="name"/></b></p>
            <dl>
                <dt>Cardinality:</dt>
                <dd><xsl:value-of select="arity"/></dd>
                <td>Datatype:</td>
                <dd><xsl:apply-templates select="datatypeName"/></dd>
            </dl>
            <xsl:apply-templates select="note"/>
        </div>
    </xsl:template>
    
    <xsl:template match="groups">
        <div class="content">
            <xsl:sequence select="_:head(.,'Groups')"/>
            <xsl:apply-templates/>
        </div>
    </xsl:template>
    
    <xsl:template match="group">
        <a id="{@ID}"/>
        <xsl:sequence select="_:head(., concat('Group: &quot;',name,'&quot;'))"/>
        <p class="block">
            <xsl:apply-templates select="description"/>
            <strong>Group Members: </strong>
            <!--<ul>-->
                <xsl:for-each select="className">
<!--                    <li>-->
                        <xsl:apply-templates select="."/>
                    <xsl:if test="following-sibling::*">,&#160;</xsl:if>
                    <!--</li>-->
                </xsl:for-each>
            <!--</ul>-->
        </p>
    </xsl:template>
    
    
    <xsl:template match="datatypeName">
        <xsl:variable name="target" select="@target"/>
        <xsl:variable name="datatype" select="//datatype[@ID = $target]/name"/>
        <xsl:variable name="vocab" select="//vocab[@ID = current()/@vocabRef]"/>
        <a href="#{$target}"><xsl:value-of select="$datatype"/></a>
        <xsl:if test="@vocabRef != ''">
            <xsl:text> in&#10;</xsl:text>
            <a href="#{@vocabRef}"><xsl:value-of select="$vocab/name"/></a>
        </xsl:if>
    </xsl:template>
    
    <xsl:template name="mkRelationsList">
        <xsl:param name="relations" as="element(relation)*"/>
        <xsl:param name="duplicate"/>
        <ul>
           <xsl:apply-templates select="$relations" mode="mkList"/>
        </ul>
    </xsl:template>
    
    <xsl:template name="entityByID">
        <xsl:param name="entityID" as="xs:string+"/>
        <xsl:variable name="entityIDSplit" select="for $i in $entityID return tokenize($i,' ')"/>
        <xsl:variable name="internal" select="$doc//@ID[. = $entityIDSplit]/.."/>
        <xsl:choose>
            <xsl:when test="exists($internal)">
                <xsl:sequence select="$internal"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:message terminate="yes">entity <xsl:value-of select="$entityID"/> not found</xsl:message>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template match="relation" mode="mkList">
        <xsl:variable name="targetClassIDs" select="targetClass/@target/tokenize(.,' ')" as="xs:string+"/>
        
        <xsl:variable name="sourceClassID" select="sourceClass/@target/tokenize(.,' ')" as="xs:string+"/>
        
        <li>
            <xsl:for-each select="$sourceClassID">
                <xsl:variable name="sourceClassDef" as="element(class)">
                    <xsl:call-template name="entityByID">
                        <xsl:with-param name="entityID" select="."/>
                    </xsl:call-template>
                </xsl:variable>
                <xsl:variable name="sourceClassName" select="$sourceClassDef/name" as="xs:string+"/>
                <a href="#{.}">&lt;<xsl:value-of select="$sourceClassName"/>&gt;</a>
                <xsl:if test="position() lt count($sourceClassID)">
                    <xsl:text>, </xsl:text>
                </xsl:if>
            </xsl:for-each>
            <xsl:text> </xsl:text>
            <a href="#{@ID}"><xsl:value-of select="name"/> (<xsl:value-of select="reverseName"/>)</a>
            <xsl:text> </xsl:text>
            <xsl:for-each select="$targetClassIDs">
                <xsl:variable name="targetClassDefinition" as="element(class)+">
                    <xsl:call-template name="entityByID">
                        <xsl:with-param name="entityID" select="."/>
                    </xsl:call-template>
                </xsl:variable>
                <xsl:variable name="targetClassName" select="$targetClassDefinition/name" as="xs:string+"/>
                <a href="#{.}">&lt;<xsl:value-of select="$targetClassName"/>&gt;</a>
                <xsl:if test="position() lt count($targetClassIDs)">
                    <xsl:text>, </xsl:text>
                </xsl:if>
            </xsl:for-each>
        </li>
    </xsl:template>
    
    
    <xsl:template match="relations" mode="mkPar">
        <xsl:param name="duplicate" as="xs:boolean" tunnel="yes" select="false()"/>
        <div class="content"><xsl:apply-templates mode="#current"/></div>
    </xsl:template>
    
    <xsl:template match="relations" mode="mkTable">
        <xsl:param name="duplicate" as="xs:boolean" tunnel="yes" select="false()"/>
        <table class="table">
            <thead>
                <tr>
                    <th>Source Class</th>
                    <th>Relation Name</th>
                    <th>Reverse Relation Name</th>
                    <th>Target Class</th>
                    <th>Properties</th>
                    <th>Remarks</th>
                </tr>
            </thead>
            <xsl:apply-templates mode="#current"/>
        </table>
    </xsl:template>
    
    <xsl:template match="relation" mode="mkPar">
        <xsl:param name="duplicate" as="xs:boolean" tunnel="yes" select="false()"/>
        <xsl:variable name="targetClassIDs" select="targetClass/@target/tokenize(.,' ')"/>
        <xsl:variable name="sourceClassIDs" select="sourceClass/@target/tokenize(.,' ')"/>
<hr></hr>
        <a id="{@ID}"/>
        <xsl:sequence select="_:head(.,concat(name,if(@type='implicit') then'*' else''))"/>
        <!--<h4 class="title is-4"><xsl:value-of select="name"/><xsl:if test="@type"><xsl:value-of select="concat(' (',@type,')')"/></xsl:if></h4>-->
        <p class="subtitle"><xsl:value-of select="reverseName"/></p>
        <xsl:if test="@status">
            <p><strong>Status: </strong><xsl:value-of select="@status"/></p>
        </xsl:if>
        <p><strong>Cardinality: </strong>
            <xsl:value-of select="string-join(*/arity,' / ')"/><br/>
            <strong>Source Class: </strong>
            <xsl:for-each select="_:entityByID($sourceClassIDs)">
                <xsl:call-template name="formatName"/>
<!--                <a href="#{.}"><xsl:value-of select="$className"/></a><xsl:text> </xsl:text>    -->
            </xsl:for-each>
            <br/>
            
            <strong>Target Class: </strong>
            <xsl:for-each select="_:entityByID($targetClassIDs)">
                <xsl:call-template name="formatName"/>
<!--                <a href="#{.}"><xsl:value-of select="$className"/></a><xsl:text> </xsl:text>    -->
            </xsl:for-each>
            <br/>
            <xsl:if test="properties/*">
                <strong>Properties: </strong><br/>
                <xsl:apply-templates select="properties" mode="mkList"/>
            </xsl:if>
        </p>
            <xsl:if test="note!=''">
                <xsl:apply-templates select="note"/>
            </xsl:if>
            <xsl:if test="CHECKME!=''">
                <xsl:apply-templates select="CHECKME"/>
            </xsl:if>
            <xsl:if test="TODO!=''">
                <xsl:apply-templates select="TODO"/>
            </xsl:if>
        <xsl:apply-templates select="examples" mode="#current"/>
    
        
<!--        <xsl:call-template name="classDependencies"/>-->
        
    </xsl:template>
    
    
    <xsl:template match="relation/examples" mode="mkPar">
        <xsl:sequence select="_:head(.,'Examples')"/>
        <xsl:apply-templates mode="#current"/>
    </xsl:template>
    
    <xsl:template name="mkExample">
        <div class="block">
            <blockquote><xsl:apply-templates/></blockquote>
            <p class="is-size-6 has-text-right">Example #<xsl:value-of select="count(preceding-sibling::example)+1"/></p>
        </div>
    </xsl:template>
    
    <xsl:template match="relation/examples/example" mode="mkPar">
        <xsl:call-template name="mkExample"/>
    </xsl:template>
    
    <xsl:template match="relation" mode="mkTable">
        <xsl:param name="duplicate" as="xs:boolean" tunnel="yes" select="false()"/>
        <xsl:variable name="targetClassID" select="targetClass/@target"/>
        <xsl:variable name="targetClassDefinition" select="doc(concat('classes/',$targetClassID,'.xml'))"/>
        <xsl:variable name="targetClassName" select="$targetClassDefinition/class/name"/>
        
        <xsl:variable name="sourceClassID" select="sourceClass/@target"/>
        <xsl:variable name="sourceClassDefinition" select="doc(concat('classes/',$sourceClassID,'.xml'))"/>
        <xsl:variable name="sourceClassName" select="$sourceClassDefinition/class/name"/>
        <tr>
            <td>
                <xsl:if test="not($duplicate)">
                    <a id="{@ID}"/>
                </xsl:if>
                <a href="#{$sourceClassID}"><xsl:value-of select="$sourceClassName"/></a>&#160;
                (<xsl:value-of select="sourceClass/arity"/>)
            </td>
            <td><xsl:value-of select="name"/></td>
            <td>(<xsl:value-of select="reverseName"/>)</td>
            <td>
                <a href="#{$targetClassID}">
                    <xsl:value-of select="$targetClassName"/>
                </a>&#160;
                (<xsl:value-of select="targetClass/arity"/>)</td>
            <td><xsl:apply-templates select="properties" mode="inCell"/></td>
            <td><xsl:apply-templates select="note" mode="inCell"/>
<!--                <xsl:call-template name="classDependencies"/>-->
            </td>
        </tr>
    </xsl:template>
    
    
    <xsl:template match="properties" mode="inCell">
        <xsl:apply-templates mode="#current"/>
    </xsl:template>
    
    <xsl:template match="property" mode="inCell">
        <p>
            <a id="{@ID}"/>
            <a href="#{datatypeName/@target}"><xsl:value-of select="name"/></a><xsl:text> </xsl:text>(<xsl:value-of select="arity"/>)
            <xsl:if test="note">
                <a id="fns{@ID}" href="#fn{@ID}" style="font-size:small; vertical-align: super,"><xsl:value-of select="count(preceding::note[ancestor::property])+1"/></a>
            </xsl:if>
        </p>
    </xsl:template>
    
    <xsl:template match="vocabularies" mode="mkTable">
        <table class="table">
            <thead>
                <tr>
                    <th>Vocabulary Name</th>
                    <th>Example Values</th>
                    <th>Remarks</th>
                </tr>
            </thead>
            <tbody>
                <xsl:for-each select="vocab">
                    <tr>
                        <td><a id="{@ID}"/><xsl:apply-templates select="name"/></td>
                        <td><xsl:value-of select="string-join(values//item,' / ')"/></td>
                        <td><xsl:apply-templates select="note" mode="inCell"/></td>
                    </tr>
                </xsl:for-each>
            </tbody>
        </table>
    </xsl:template>
    
    <xsl:template match="vocab/*">
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="ref/@uri">
        <xsl:attribute name="href" select="."/>
    </xsl:template>
    
    <xsl:template match="p">
        <p class="block"><xsl:apply-templates/></p>
    </xsl:template>
    
    <xsl:template match="list">
        <ul>
            <xsl:apply-templates select="@*|node()"/>
        </ul>
    </xsl:template>
    
    <xsl:template match="item">
        <li>
            <xsl:apply-templates select="@*|node()"/>
        </li>
    </xsl:template>
    
    <xsl:template match="b">
        <b><xsl:apply-templates select="@*|node()"/></b>
    </xsl:template>
    
    <xsl:template match="i">
        <i><xsl:apply-templates select="@*|node()"/></i>
    </xsl:template>
    
    <xsl:template match="ref">
        <a href="{@target}">
            <xsl:apply-templates select="@*|node()"/>
        </a>
    </xsl:template>
    
    <xsl:template match="datatypeName/@target|ref/@target[not(starts-with(.,'#'))]" priority="2">
        <xsl:attribute name="target" select="concat('#',.)"/>
    </xsl:template>
    
    <xsl:template match="datatypes" mode="mkTable">
        <table class="table">
            <thead>
                <tr>
                    <th>Name</th>
                    <th>Used by</th>
                    <th>Remarks</th>
                </tr>
            </thead>
            <tbody>
                <xsl:apply-templates mode="#current">
                    <xsl:sort select="name"/>
                </xsl:apply-templates>
            </tbody>
        </table>
    </xsl:template>
    
    <xsl:template match="datatypes" mode="mkPar">
        <xsl:apply-templates>
            <xsl:sort select="name"/>
        </xsl:apply-templates>
    </xsl:template>
    
    <xsl:template match="datatype" mode="mkTable">
        <xsl:variable name="users" select="//property[datatypeName/@target = current()/@ID]" as="item()*"/>
        <tr>
            <td><a id="{@ID}"/><xsl:value-of select="name"/></td>
            <td>
                <xsl:for-each select="$users">
                    <xsl:sort select="(ancestor::class|ancestor::relation)[1]" order="ascending"/>
                    <xsl:sort select="name" order="ascending"/>
                    <a href="#{@ID}"><xsl:value-of select="ancestor::*[@ID][1]/@ID"/><xsl:text>.</xsl:text><xsl:value-of select="name"/></a>
                    <xsl:if test="position() lt count($users)">, </xsl:if>
                </xsl:for-each>
            </td>
            <td>
                <xsl:apply-templates select="note" mode="inCell"/>
            </td>
        </tr>
    </xsl:template>
    
    <xsl:template match="datatype" mode="mkPar">
        <xsl:variable name="users" select="//property[datatypeName/@target = current()/@ID]" as="item()*"/>
        <p>
            <a id="{@ID}"/>
            <b><xsl:value-of select="name"/>: </b>
            <xsl:apply-templates select="note"/>
            <xsl:text> – Used by: </xsl:text>
                <xsl:for-each select="$users">
                    <xsl:sort select="ancestor::class|ancestor::relation" order="ascending"/>
                    <xsl:sort select="name" order="ascending"/>
                    <a href="#{@ID}"><xsl:value-of select="ancestor::*[@ID][1]/@ID"/><xsl:text>.</xsl:text><xsl:value-of select="name"/></a>
                    <xsl:if test="position() lt count($users)">, </xsl:if>
                </xsl:for-each>
        </p>
    </xsl:template>
    
   <xsl:template match="className | fieldName | vocabName | propName | relName | instanceName | tag">
       <xsl:call-template name="formatName"/>
   </xsl:template>
    
    <xsl:template match="path">
        <code>
            <xsl:apply-templates/>
        </code>
    </xsl:template>
    
   <xsl:template name="formatName">
       <xsl:param name="entityType" as="xs:string?"/>
       <xsl:variable name="name" select="."/>
       <xsl:variable name="isExternal" select="if (exists($doc/namespace)) then matches(.,concat('^(',string-join($doc//namespaces/namespace/@prefix/concat(.,':'),'|'),')')) else if (ancestor::mapping) then true() else false()"/>
       <xsl:choose>
           <xsl:when test="$isExternal">
               <code><xsl:apply-templates/></code>
           </xsl:when>
           <xsl:otherwise>
               <xsl:variable name="entityDef" as="element()?">
                   <xsl:choose>
                       <xsl:when test="$name instance of element(instanceName)">
                           <xsl:sequence select="_:entityByID(@classRef|@target)"/>
                       </xsl:when>
                       <xsl:when test="$name/self::name[parent::class] or $name/self::class">
                           <xsl:sequence select="ancestor-or-self::class"/>
                       </xsl:when>
                       <xsl:when test="$name instance of xs:string">
                           <xsl:message select="$name"></xsl:message>
                           <xsl:sequence select="_:entityByName($name)"/>
                       </xsl:when>
                       <xsl:when test="normalize-space(@target) != ''">
                           <xsl:sequence select="_:entityByID(@target)"/>
                       </xsl:when>
                       <xsl:when test="ancestor-or-self::class">
                           <xsl:sequence select="ancestor-or-self::class"/>
                       </xsl:when>
                       <xsl:when test="local-name(.) = 'className' and  . != ''">
                           <xsl:sequence select="_:entityByName(.)"/>
                       </xsl:when>
                       
                   </xsl:choose>
               </xsl:variable>
               
               <xsl:if test="not($entityDef)">
                   <xsl:message select="."/>
                   <xsl:message terminate="yes">UNKNOWN entity with name "<xsl:value-of select="$name"/>".</xsl:message>
               </xsl:if>
               <xsl:variable name="entityType">
                   <xsl:choose>
                       <xsl:when test="$entityType != ''">
                           <xsl:value-of select="$entityType"/>
                       </xsl:when>
                       <xsl:when test="local-name(.) = ('instanceName')">
                           <xsl:value-of select="local-name(.)"/>
                       </xsl:when>
                       <xsl:when test="local-name(.) = ('class')">className</xsl:when>
                       <xsl:otherwise><xsl:value-of select="local-name($entityDef)"/></xsl:otherwise>
                   </xsl:choose>
               </xsl:variable>
               
               <xsl:variable name="entityName">
                   <!-- if it the reference contains text, we just use that, otherwise 
                       we take the name of the entity -->
                   <xsl:choose>
                       <xsl:when test=". instance of element(class)">
                           <xsl:sequence select="$entityDef/name"/>
                       </xsl:when>
                       <xsl:when test="self::name[parent::class]">
                           <xsl:sequence select="."/>
                       </xsl:when>
                       <xsl:when test=". != ''">
                           <xsl:value-of select="."/>
                       </xsl:when>
                       <xsl:when test="@target != ''">
                           <xsl:value-of select="$entityDef/name"/>
                       </xsl:when>
                       <xsl:otherwise>UNKNOWN_<xsl:value-of select="upper-case($entityType)"/></xsl:otherwise>
                   </xsl:choose>
               </xsl:variable>
               
               <xsl:variable name="formattedContent">
                   <xsl:choose>
                       <xsl:when test="$entityType = ('class','className')">&lt;<xsl:value-of select="upper-case($entityName)"/>&gt;</xsl:when>
                       <xsl:when test="$entityType = ('instanceName', 'instance')"><i><xsl:value-of select="$entityName"/></i></xsl:when>
                       <xsl:when test="$entityType = 'propertyName'">
                           <i><a role="{local-name()}" href="#{$entityDef/@ID}"><xsl:value-of select="$entityName"/></a></i>
                       </xsl:when>
                       <xsl:when test="$entityType = 'relation' and @target != ''">
                           <xsl:variable name="relationID" select="@target" as="xs:string"/>
                           <xsl:variable name="relation" select="_:entityByID($relationID)" as="element(relation)"/>
                           <xsl:variable name="sourceClass" select="_:entityByID($relation/sourceClass/@target)" as="element(class)+"/>
                           <xsl:variable name="targetClass" select="_:entityByID($relation/targetClass/@target)" as="element(class)+"/>
                           <xsl:if test=". = ''">
                               <xsl:for-each select="$sourceClass/name">
                                   <xsl:call-template name="formatName">
                                       <xsl:with-param name="entityType">class</xsl:with-param>
                                   </xsl:call-template>
                                   <xsl:if test="position() lt count($sourceClass)"> / </xsl:if>
                               </xsl:for-each>
                               <xsl:text> </xsl:text>
                           </xsl:if>
                           <i><a role="{local-name()}" href="#{$entityDef/@ID}"><xsl:value-of select="$entityName"/></a></i>
                           <xsl:if test=". = ''">
                               <xsl:text> </xsl:text>
                               <xsl:for-each select="$targetClass/name">
                                     <xsl:call-template name="formatName">
                                         <xsl:with-param name="entityType">class</xsl:with-param>
                                     </xsl:call-template>
                               </xsl:for-each>
                           </xsl:if>
                       </xsl:when>
                       <xsl:otherwise><xsl:value-of select="$entityName"/></xsl:otherwise>
                   </xsl:choose>
               </xsl:variable>
               
               
               <xsl:choose>
                   <xsl:when test="$entityType = ('relation','instanceName')">
                       <xsl:sequence select="$formattedContent"/>
                   </xsl:when>
                   <xsl:when test=". instance of element() and @target != ''">
                       <a role="{local-name()}" href="#{@target}">
                           <xsl:sequence select="$formattedContent"/>
                       </a>
                   </xsl:when>
                   <xsl:when test="self::class">
                       <a role="{local-name()}" href="#{@ID}">
                           <xsl:sequence select="$formattedContent"/>
                       </a>
                   </xsl:when>
                   <xsl:when test="exists(_:entityByName(.))">
                       <xsl:variable name="entityByName" select="_:entityByName(.)"/>
                       <xsl:choose>
                           <xsl:when test="count($entityByName) gt 1">
                               <xsl:message>More than one entity found for name '<xsl:value-of select="."/>'</xsl:message>
                               <xsl:sequence select="$formattedContent"/>
                           </xsl:when>
                           <xsl:otherwise>
                               <a href="#{$entityByName/@ID}"><xsl:sequence select="$formattedContent"/></a>
                           </xsl:otherwise>
                       </xsl:choose>
                   </xsl:when>
                   <xsl:otherwise>
                       <code><xsl:sequence select="$formattedContent"/></code>
                   </xsl:otherwise>
               </xsl:choose>
               
           </xsl:otherwise>
       </xsl:choose>
       <xsl:if test=". instance of element() and self::instanceName[@classRef]"> (a <a href="#{@classRef}">&lt;<xsl:value-of select="_:entityByID(@classRef)/upper-case(name)"/>&gt;</a>)</xsl:if>
   </xsl:template>
</xsl:stylesheet>