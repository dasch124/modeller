<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns="http://www.w3.org/1999/xhtml"
    xmlns:html="http://www.w3.org/1999/xhtml"
    xmlns:_="urn:local"
    exclude-result-prefixes="#all"
    version="2.0">  
    <xsl:param name="debug">false</xsl:param>
    <xsl:param name="pathToModelDir"/>
    <xsl:param name="pathToModelDot"/>
    <xsl:variable name="doc" select="root(.)"/>
    <xsl:output method="xhtml" indent="yes"/>
    <xsl:strip-space elements="*"/>
    <xsl:preserve-space elements="p"/>
    <xsl:function name="_:head">
        <xsl:param name="item" as="item()*"/>
        <xsl:param name="text"/>
        <xsl:variable name="hl" select="if ($item instance of xs:integer) then $item else count($item/ancestor::*[self::classes|self::class|self::model|self::property|self::relation])"/>
        <xsl:element name="h{$hl}">
            <xsl:value-of select="$text"/>
        </xsl:element>
    </xsl:function>

    <xsl:function name="_:head">
        <xsl:param name="item" as="item()*"/>
        <xsl:sequence select="_:head($item, data($item))"/>
    </xsl:function>
   
    <xsl:template match="/">
        <xsl:if test="$debug = 'true'">
            <xsl:message>$pathToModelDir = <xsl:value-of select="$pathToModelDir"/></xsl:message>
            <xsl:message>$pathToModelDot = <xsl:value-of select="$pathToModelDot"/></xsl:message>
        </xsl:if>
        <html>
            <head>
                <title><xsl:value-of select="/model/meta/title"/></title>
                <link rel="stylesheet" href="https://unpkg.com/spectre.css/dist/spectre.min.css">&#160;</link>
            </head>
            <body>  
                <div class="container">
                    <h1><xsl:value-of select="/model/meta/title"/></h1>
                    <header>
                        <table class="table">
                            <tr>
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
               </div>
                <main>
                    <h2>Graphical Overview</h2>
                    <figure class="figure">
                        <xsl:choose>
                            <xsl:when test="ends-with($pathToModelDot,'svg')">
                                <xsl:sequence select="doc(concat($pathToModelDir,'/',tokenize($pathToModelDot,'/')[last()]))"/>
                            </xsl:when>
                            <xsl:otherwise>
                                <img src="{$pathToModelDot}" class="img-responsive img-fit-contain"/>
                            </xsl:otherwise>
                        </xsl:choose>
                        <figcaption class="figure-caption text-center">Graphical Overview of the data model.<br/>Dashed lines mean implicit shortcut relations.</figcaption>
                    </figure>
                    <xsl:apply-templates/>
                </main>
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
    <xsl:template match="description|classes|relations|vocabularies|class/definition|class/examples|class/properties|class/note|datatypes|mapping">
        <xsl:variable name="head" select="concat(upper-case(substring(local-name(.),1,1)),substring(local-name(.),2))"/>
        <xsl:if test="*">
            <div>
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
                    <xsl:when test="self::note[parent::class]">
                        <xsl:sequence select="_:head(., 'Remarks on this class')"/>
                        <xsl:apply-templates/>
                    </xsl:when>
                    <xsl:when test="self::mapping">
                        <xsl:sequence select="_:head(., concat($head, ' to ', @targetLanguage, if (@version = '') then '' else concat(' v. ',@version)))"/>
                        <p><xsl:apply-templates select="@* except (@targetLanguage, @version)"/></p>
                        <xsl:apply-templates select="node()"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:sequence select="_:head(., $head)"/>
                        <xsl:apply-templates select="node()"/>
                    </xsl:otherwise>
                </xsl:choose>
            </div>
        </xsl:if>
    </xsl:template>
    
    <xsl:template match="mapping/@level">
        <xsl:text>Mapping Level: </xsl:text><xsl:value-of select="."/>
    </xsl:template>
    <xsl:template match="mapping/note[not(*)]">
        <p>NB: <xsl:apply-templates/></p>
    </xsl:template>
    <xsl:template match="mapping/note[*]">
        NB: <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="code">
        <pre style="border: 1px solid black;">
            <code>
                <xsl:sequence select="node()"/>
            </code>
        </pre>
    </xsl:template>
    
    <xsl:template match="class">
        <div>
            <a id="{@ID}"/>
            <xsl:sequence select="_:head(., name)"/>
            <xsl:apply-templates/>
            
            <xsl:variable name="relsOut">
                <xsl:call-template name="filterRelations">
                    <xsl:with-param name="className" select="name"/>
                    <xsl:with-param name="direction" select="'outgoing'"/>
                </xsl:call-template>
            </xsl:variable>
            
            <div>
                <xsl:sequence select="_:head(3, 'Relations (outgoing)')"/>
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
                    <xsl:with-param name="className" select="name"/>
                    <xsl:with-param name="direction" select="'incoming'"/>
                </xsl:call-template>
            </xsl:variable>

            <div>
                <xsl:sequence select="_:head(3, 'Relations (incoming)')"/>
                <xsl:choose>
                    <xsl:when test="not($relsIn//html:li)">
                        <p>No outgoing relations defined.</p>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:sequence select="$relsIn"/>
                    </xsl:otherwise>
                </xsl:choose>
            </div>
            <xsl:if test="@parent!=''">
                <p>(TODO list inherited properties and relations)</p>
            </xsl:if>
        </div>
    </xsl:template>
    
    <xsl:template name="filterRelations">
        <xsl:param name="className"/>
        <xsl:param name="direction"/>
        <xsl:variable name="relations" as="element(relation)*">
            <xsl:sequence select="root()//relation[if ($direction = 'incoming') then targetClass/@target = $className else sourceClass/@target = $className]"/>    
        </xsl:variable>
        <xsl:message select="$className||' '||$direction||' '||count($relations)"/>
        <xsl:call-template name="mkRelationsList">
            <xsl:with-param name="relations" select="$relations"/>
            <xsl:with-param name="duplicate" select="true()" as="xs:boolean" tunnel="yes"/>
        </xsl:call-template>
    </xsl:template>
    
    <xsl:template match="class/name"/>
    
    <xsl:template match="properties" mode="mkTable">
        <table class="table">
            <thead>
                <tr>
                    <th>Property Name / Occurrences</th>
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
                <xsl:text>Occurrences: </xsl:text><xsl:value-of select="arity"/> 
            </td>
            <td><xsl:apply-templates select="datatypeRef"/></td>
            <td><xsl:apply-templates select="note"/></td>
        </tr>
    </xsl:template>
    
    <xsl:template match="properties" mode="mkPar">
        <xsl:apply-templates mode="#current">
            <xsl:sort select="name"/>
        </xsl:apply-templates>
    </xsl:template>
    
    <xsl:template match="property" mode="mkPar">
        <div class="property">
            <p><a id="{@ID}"/>Property: <b><xsl:value-of select="name"/></b><br/>
                Occurrences: <xsl:value-of select="arity"/><br/>
                Datatype: <xsl:apply-templates select="datatypeRef"/>
            </p>
            <p>Remarks:</p>
            <xsl:apply-templates select="note"/></div>
    </xsl:template>
    
    
    <xsl:template match="datatypeRef">
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
    
    <xsl:template name="classByID">
        <xsl:param name="classID" as="xs:string"/>
        <xsl:variable name="internal" select="$doc//class[@ID = $classID]"/>
        <xsl:variable name="externalPaths">
            <xsl:value-of select="concat($pathToModelDir,'/classes/',$classID,'.xml')"/>
            <xsl:value-of select="concat($pathToModelDir,'/',$classID,'.xml')"/>
        </xsl:variable> 
        <xsl:choose>
            <xsl:when test="exists($internal)">
                <xsl:sequence select="$internal"/>
            </xsl:when>
            <xsl:when test="some $path in $externalPaths satisfies doc-available($path)">
                <xsl:sequence select="$externalPaths[doc-available(.)]"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:message terminate="yes">class <xsl:value-of select="$classID"/> not found</xsl:message>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template match="relation" mode="mkList">
        <xsl:variable name="targetClassID" select="targetClass/@target" as="xs:string"/>
        <xsl:variable name="targetClassDefinition" as="element(class)">
            <xsl:call-template name="classByID">
                <xsl:with-param name="classID" select="$targetClassID"/>
            </xsl:call-template>
        </xsl:variable>
        <xsl:variable name="targetClassName" select="$targetClassDefinition/name" as="xs:string"/>
        
        <xsl:variable name="sourceClassID" select="sourceClass/@target"/>
        <xsl:variable name="sourceClassDefinition" as="element(class)">
            <xsl:call-template name="classByID">
                <xsl:with-param name="classID" select="$sourceClassID"/>
            </xsl:call-template>
        </xsl:variable>
        <xsl:variable name="sourceClassName" select="$sourceClassDefinition/name" as="xs:string"/>
        <li>
            <a href="#{$sourceClassID}">&lt;<xsl:value-of select="$sourceClassName"/>&gt;</a>
            <xsl:text> </xsl:text>
            <a href="#{@ID}"><xsl:value-of select="name"/> (<xsl:value-of select="reverseName"/>)</a>
            <xsl:text> </xsl:text>
            <a href="#{$targetClassID}">&lt;<xsl:value-of select="$targetClassName"/>&gt;</a>
        </li>
    </xsl:template>
    
    
    <xsl:template match="relations" mode="mkPar">
        <xsl:param name="duplicate" as="xs:boolean" tunnel="yes" select="false()"/>
        <xsl:apply-templates mode="#current"/>
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
        <xsl:variable name="targetClassID" select="targetClass/@target"/>
        <xsl:variable name="targetClassDefinition">
            <xsl:call-template name="classByID">
                <xsl:with-param name="classID" select="$targetClassID"/>
            </xsl:call-template>
        </xsl:variable>
        <xsl:variable name="targetClassName" select="$targetClassDefinition/class/name"/>
        
        <xsl:variable name="sourceClassID" select="sourceClass/@target"/>
        <xsl:variable name="sourceClassDefinition">
            <xsl:call-template name="classByID">
                <xsl:with-param name="classID" select="$sourceClassID"/>
            </xsl:call-template>
        </xsl:variable>
        <xsl:variable name="sourceClassName" select="$sourceClassDefinition/class/name"/>
        <a id="{@ID}"/>
        <h4><xsl:value-of select="name"/><xsl:if test="@type"><xsl:value-of select="concat(' (',@type,')')"/></xsl:if></h4>
<!--        <xsl:call-template name="classDependencies"/>-->
        <p>
            Occurrences: <xsl:value-of select="string-join(*/arity,' / ')"/><br/>
            Source Class: <a href="#{$sourceClassID}"><xsl:value-of select="$sourceClassName"/></a><br/>
            Target Class: <a href="#{$targetClassID}"><xsl:value-of select="$targetClassName"/></a><br/>
            Reverse Name: <xsl:value-of select="reverseName"/><br/>
            <xsl:if test="properties/*">
                Properties: <br/><xsl:apply-templates select="properties" mode="mkTable"/><br/>
            </xsl:if>
            <xsl:if test="note!=''">
                Remarks: <xsl:apply-templates select="note"/>
            </xsl:if>
        </p>
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
            <td><xsl:apply-templates select="note"/>
<!--                <xsl:call-template name="classDependencies"/>-->
            </td>
        </tr>
    </xsl:template>
    
    
    <xsl:template name="classDependencies">
        <xsl:if test="@parent!=''">
            <p>Subclass of <a href="#{@parent}"><xsl:value-of select="id(current()/@parent)//name"/></a></p>
        </xsl:if>
        <xsl:if test="exists(//relation[@parent = current()/@ID])">
            <p>Superclass of 
                <xsl:for-each select="//relation[@parent = current()/@ID]">
                    <a href="#{@ID}"><xsl:value-of select="name"/></a>
                </xsl:for-each>
            </p>
        </xsl:if>
    </xsl:template>
    
    <xsl:template match="properties" mode="inCell">
        <xsl:apply-templates mode="#current"/>
    </xsl:template>
    
    <xsl:template match="property" mode="inCell">
        <p>
            <a id="{@ID}"/>
            <a href="#{datatypeRef/@target}"><xsl:value-of select="name"/></a><xsl:text> </xsl:text>(<xsl:value-of select="arity"/>)
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
                        <td><xsl:apply-templates select="note"/></td>
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
        <p><xsl:apply-templates/></p>
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
    
    <xsl:template match="datatypeRef/@target|ref/@target[not(starts-with(.,'#'))]" priority="2">
        <xsl:attribute name="target" select="concat('#',.)"/>
    </xsl:template>
    
    <xsl:template match="datatypes" mode="mkTable">
        <xsl:apply-templates>
            <xsl:sort select="name"/>
        </xsl:apply-templates>
    </xsl:template>
    
    <xsl:template match="datatype">
        <xsl:variable name="users" select="//property[datatypeRef/@target = current()/@ID]" as="item()*"/>
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
    
   <xsl:template match="className | fieldName | vocabName | propName | relName">
       <a role="{local-name()}" href="#{if (@target) then @target else .}"><xsl:value-of select="."/></a>
   </xsl:template>
</xsl:stylesheet>