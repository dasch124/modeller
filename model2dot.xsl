<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:tei="http://www.tei-c.org/ns/1.0"
    exclude-result-prefixes="xs"
    version="2.0">
    <xsl:output method="text"/>
    <xsl:strip-space elements="*"/>
    
    <xsl:param name="showAbstractSuperclasses">true</xsl:param>
    <xsl:param name="showProperties">false</xsl:param>
    <xsl:param name="showCardinalities">false</xsl:param>
    <xsl:param name="nodesep">1</xsl:param>
    <xsl:param name="ranksep">1</xsl:param>
    <xsl:param name="labeldistance">1.0</xsl:param>
    <xsl:param name="labelfloat">false</xsl:param>
    <xsl:variable name="doc" select="root()" as="document-node()"/>
    <xsl:variable name="subclassStyle">
        <xsl:text>style = dotted&#10;color = gray&#10;fontcolor = gray</xsl:text>
    </xsl:variable>
    <xsl:variable name="implicitRelationStyle">
        <xsl:text>style=dashed
                color = gray
                fontcolor = gray</xsl:text>
    </xsl:variable>
    <xsl:template match="/">
        digraph <xsl:value-of select="replace(model/meta/title,'\s+','')"/> {
            node [fontname = "Bitstream Vera Sans" fontsize = "8" shape = "record" rankdir="TB"]
            edge [fontname = "Bitstream Vera Sans" fontsize = "8" ]    
            nodesep = <xsl:value-of select="$nodesep"/>
            ranksep = <xsl:value-of select="$ranksep"/>
            TBbalance = "max"
            label = "<xsl:value-of select="model/meta/title"/>"
        
            <xsl:apply-templates select="//class"/>
            <xsl:choose>
                <xsl:when test="$showCardinalities = 'true'">
                    <xsl:call-template name="relations-showCardinalities"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:call-template name="relations-hideCardinalities"/>
                </xsl:otherwise>
            </xsl:choose>
        
            <xsl:apply-templates select="//group"/>
        
            <!--subgraph clusterLegende {
                label = "Legend" 
                rankdir=LR
                fontsize="6"
                A; B; C; D [
                    shape = hidden
                ]
                A -> B [
                    label="shortcut"
                    <xsl:value-of select="$implicitRelationStyle"/>
                ]
                
                C -> D [
                    label="subclass"
                    <xsl:value-of select="$subclassStyle"/>
                ]
            }-->
        }
    </xsl:template>
    
    <xsl:template match="group">
        subgraph <xsl:value-of select="concat('cluster',@ID)"/> {
            <xsl:text>rank="min"</xsl:text>
            <xsl:text>fontsize="9"</xsl:text>
            <xsl:value-of select="name/concat('label=&quot;',.,'&quot;&#10;')"/>
            <xsl:for-each select="className">
                <xsl:value-of select="@target"/><xsl:text>;&#10;</xsl:text>
            </xsl:for-each>
        }
    </xsl:template>
    
    <xsl:template match="class[@type = 'abstract'][$showAbstractSuperclasses = 'false']"/>

    <xsl:template match="class/properties/property">
        <xsl:value-of select="concat('+ ',name)"/>
        <xsl:if test="datatypeRef">
            <xsl:variable name="target" select="datatypeRef/@target"/>
            <xsl:variable name="datatype" select="root()//*[@ID = $target]"/>
            <xsl:value-of select="$datatype/name/concat(' : ',.)"/>
        </xsl:if>
        <xsl:if test="$showCardinalities = 'true'">
            <xsl:value-of select="arity/concat(' (',.,')')"/>
        </xsl:if>
        <xsl:text xml:space="preserve">\l\&#10;</xsl:text>
    </xsl:template>

    <xsl:template match="relation/properties/property">
        <xsl:value-of select="concat('+ ',name)"/>
        <xsl:if test="datatypeRef">
            <xsl:variable name="target" select="datatypeRef/@target"/>
            <xsl:variable name="datatype" select="root()//*[@ID = $target]"/>
            <xsl:value-of select="$datatype/name/concat(' : ',.)"/>
        </xsl:if>
        <xsl:if test="$showCardinalities = 'true'">
            <xsl:value-of select="arity/concat(' (',.,')')"/>
        </xsl:if>
        <xsl:text xml:space="preserve">\l\&#10;</xsl:text>
    </xsl:template>
    
        
    <xsl:template match="class">
        <xsl:variable name="parent" select="@parent"/>
        <xsl:variable name="superclass" select="root()//class[@ID = $parent]" as="element(class)*"/>
        <xsl:variable name="props">
            <xsl:if test="$showProperties = 'true'">
                <xsl:text>|</xsl:text>
                <xsl:apply-templates select="properties/property"/>
                <xsl:if test="$showAbstractSuperclasses = 'false'">
                    <xsl:apply-templates select="$superclass//property"/>
                </xsl:if>
            </xsl:if>
        </xsl:variable>
        <xsl:value-of select="@ID"/> [
            label = "{<xsl:value-of select="name"/><xsl:value-of select="$props"/>}"
            labeltooltip = "<xsl:value-of select="replace(string-join((definition),'&#10;'),'&quot;','\\&quot;')"/>"
            URL = "<xsl:value-of select="concat('#',@ID)"/>"
            <xsl:if test="@type = 'abstract'">
                color=gray
            </xsl:if>
        ]
        <xsl:if test="@parent != '' and (if ($showAbstractSuperclasses = 'false') then $superclass/@type != 'abstract' else true())">
            <xsl:value-of select="@ID"/> [
                color = gray
            ]
            <xsl:value-of select="@parent"/> -> <xsl:value-of select="@ID"/> [
                <xsl:value-of select="$subclassStyle"/>
                label = "has subclass"
            ]
        </xsl:if>
    </xsl:template>
    
    
    <xsl:template match="relation[$showCardinalities = 'true' or $showProperties = 'true']">
        <xsl:variable name="sourceClassDef" select="for $sourceID in tokenize(current()/sourceClass/@target,'\s+') return root()//class[@ID = $sourceID]" as="element(class)+"/>
        <xsl:variable name="sourceClassID" select="if ($showAbstractSuperclasses = 'false' and $sourceClassDef/@type = 'abstract') then root(.)//class[@parent = $sourceClassDef/@ID]/@ID else $sourceClassDef/@ID" as="attribute(ID)+"/>
        
        <xsl:variable name="targetClassDef" select="for $targetID in tokenize(current()/targetClass/@target,'\s+') return root()//class[@ID = $targetID]" as="element(class)+"/>
        <xsl:variable name="targetClassID" select="if ($showAbstractSuperclasses = 'false' and $targetClassDef/@type = 'abstract') then root(.)//class[@parent = $targetClassDef/@ID]/@ID else $targetClassDef/@ID" as="attribute(ID)+"/>
        
        <xsl:variable name="label" select="name"/>
        <xsl:variable name="attributes">
            [
            label = "<xsl:value-of select="$label"/>"
            URL = "<xsl:value-of select="concat('#',@ID)"/>"
            labeltooltip = "<xsl:value-of select="replace(string-join((note,properties),'&#10;'),'&quot;','\\&quot;')"/>"
            labelfloat = <xsl:value-of select="$labelfloat"/>
            labeldistance = <xsl:value-of select="$labeldistance"/>
            taillabel = "<xsl:value-of select="sourceClass/arity"/>"
            headlabel = "<xsl:value-of select="targetClass/arity"/>"
            shape = "record"
            
            <xsl:if test="@type = 'implicit'">
                <xsl:value-of select="$implicitRelationStyle"/>
            </xsl:if>
            ]
        </xsl:variable>
        <xsl:for-each select="$sourceClassDef/@ID">
            <xsl:variable name="scID" select="."/>
            <xsl:for-each select="$targetClassDef/@ID">
                <xsl:variable name="tcID" select="."/>
                <xsl:value-of select="$scID"/> -> <xsl:value-of select="$tcID"/> <xsl:value-of select="$attributes"/>
            </xsl:for-each>
        </xsl:for-each>
<!--        <xsl:value-of select="$sourceClassDef/@ID"/> -> <xsl:value-of select="$targetClassDef/@ID"/> <xsl:value-of select="$attributes"/>-->

    <!-- CHECKME This clutters the graph, so commenting out for the moment -->
        <!--<xsl:if test="$sourceClassDef/@ID != $sourceClassID or $targetClassDef/@ID != $targetClassID">
            <xsl:for-each select="distinct-values($sourceClassID)">
                <xsl:variable name="s" select="."/>
                <xsl:for-each select="distinct-values($targetClassID)">
                    <xsl:value-of select="$s"/> -> <xsl:value-of select="."/>
                    <xsl:value-of select="$attributes"/>
                </xsl:for-each>
            </xsl:for-each>
        </xsl:if>-->
    
    </xsl:template>
    
    
    <xsl:template name="relations-showCardinalities"/>
    
    <xsl:template name="relations-hideCardinalities">
        <xsl:variable name="allRelations" select="root()//relation" as="element(relation)*"/>
        <xsl:variable name="sourceClasses" select="distinct-values($allRelations/sourceClass/@target/tokenize(.,' '))" as="xs:string*"/>
        <xsl:variable name="targetClasses" select="distinct-values($allRelations/targetClass/@target/tokenize(.,' '))" as="xs:string*"/>
        <xsl:variable name="types" select="distinct-values($allRelations/@type)"/>
        <xsl:for-each select="$sourceClasses">
            <xsl:variable name="sourceClass" select="."/>
            <xsl:for-each select="$targetClasses">
                <xsl:variable name="targetClass" select="."/>
                <xsl:for-each select="($types,'')">
                    <xsl:variable name="type" select="."/>
                    <xsl:variable name="relations" select="$allRelations[tokenize(sourceClass/@target, '\s+') = $sourceClass][tokenize(targetClass/@target, '\s+') = $targetClass][if ($type!='') then @type = $type else true()]" as="element(relation)*"/>
                    <xsl:if test="exists($relations)">
                        <xsl:variable name="sourceClassDef" select="$doc//class[@ID = $sourceClass]" as="element(class)"/>
                        <xsl:variable name="sourceClassID" select="if ($showAbstractSuperclasses = 'false' and $sourceClassDef/@type = 'abstract') then $doc//class[@parent = $sourceClassDef/@ID]/@ID else $sourceClassDef/@ID" as="attribute(ID)+"/>
                        <xsl:variable name="targetClassDef" select="$doc//*[@ID = $targetClass]" as="element(class)"/>
                        <xsl:variable name="targetClassID" select="if ($showAbstractSuperclasses = 'false' and $targetClassDef/@type = 'abstract') then $doc//class[@parent = $targetClassDef/@ID]/@ID else $targetClassDef/@ID" as="attribute(ID)+"/>
                        
                        <xsl:variable name="s" select="$sourceClassID"/>
                        <xsl:variable name="t" select="$targetClassID"/>
                        
                        
                        <xsl:value-of select="$s"/> -> <xsl:value-of select="$t"/> [
                        
                        <xsl:text>label = "</xsl:text><xsl:value-of select="string-join($relations/name,'&#10;')"/><xsl:text>"</xsl:text><!--<xsl:for-each select="$relations">
<!-\-                            <xsl:text disable-output-escaping="yes">&lt;a href="#</xsl:text><xsl:value-of select="@ID"/><xsl:text disable-output-escaping="yes">"&gt;</xsl:text><xsl:value-of select="name"/><xsl:text disable-output-escaping="yes">&lt;/a&gt;&lt;br/&gt;</xsl:text>-\->
                            <xsl:value-of select="name"/><xsl:text>&lt;BR/&gt;</xsl:text>
                        </xsl:for-each>-->
                        labelfloat = <xsl:value-of select="$labelfloat"/>
                        URL = "<xsl:value-of select="concat('#',$relations[1]/@ID)"/>"
                        <xsl:if test="$type = 'implicit'">
                            style=dashed
                            color = gray
                            fontcolor = gray
                        </xsl:if>
                        ]
                        
                    </xsl:if>
                </xsl:for-each>
            </xsl:for-each>
        </xsl:for-each>
    </xsl:template>
</xsl:stylesheet>