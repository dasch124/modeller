<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:h="http://www.w3.org/1999/xhtml"
    xmlns="http://www.w3.org/1999/xhtml"
    exclude-result-prefixes="#all"
    version="2.0">
    <xsl:param name="listingHtmlFilenamePattern"/>
    
    <xsl:template match="/">    
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="node() | @*">
        <xsl:copy>
            <xsl:apply-templates select="node() | @*"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="h:code">
        <xsl:variable name="position" select="count(preceding::h:code)+1"/>
        <xsl:variable name="htmlFilename" select="replace($listingHtmlFilenamePattern,'#',xs:string($position))"/>
        <code>
            <xsl:sequence select="doc($htmlFilename)//pre"/>
        </code>
    </xsl:template>
</xsl:stylesheet>