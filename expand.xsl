<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    exclude-result-prefixes="xs"
    version="2.0">
    <xsl:param name="stripNamespaces">false</xsl:param>
    
    <xsl:template match="@ID" priority="1">
        <xsl:param name="isInherited" as="xs:boolean?" tunnel="yes"/>
        <xsl:param name="copyTo" tunnel="yes"/>
        <xsl:choose>
            <xsl:when test="$isInherited">
                <xsl:attribute name="ID" select="concat(lower-case($copyTo),'.',.)"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:copy-of select="."/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template match="property[not(note)]">
        <xsl:param name="parentRef" tunnel="yes"/>
        <xsl:param name="isInherited" tunnel="yes" as="xs:boolean?"/>
        <xsl:copy>
            <xsl:apply-templates select="@*|node()"/>
            <xsl:if test="$isInherited">
                <note>
                    <p>Inherited from <xsl:sequence select="$parentRef"/></p>
                </note>
            </xsl:if>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="property/note">
        <xsl:param name="parentRef" tunnel="yes"/>
        <xsl:param name="isInherited" tunnel="yes" as="xs:boolean?"/>
        <xsl:copy>
            <xsl:apply-templates select="@*|node()"/>
            <xsl:if test="$isInherited">
                <p>Inherited from <xsl:sequence select="$parentRef"/></p>
            </xsl:if>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="node() | @*">
        <xsl:copy>
            <xsl:apply-templates select="node() | @*"/>
        </xsl:copy>
    </xsl:template>
    
    
<xsl:template match="properties">
    <xsl:param name="parentProperties" tunnel="yes"/>
    <xsl:copy>
        <xsl:apply-templates select="@*|node()"/>
        <xsl:apply-templates select="$parentProperties">
            <xsl:with-param name="isInherited" select="true()" tunnel="yes"/>
        </xsl:apply-templates>
    </xsl:copy>
</xsl:template>
    

    <xsl:template match="*[@parent]">
        <xsl:variable name="id" select="@ID"/>
        <xsl:variable name="parentID" select="@parent"/>
        <xsl:variable name="parent" select="root()//*[@ID = $parentID]"/>
        <xsl:variable name="parentProperties" select="$parent/properties/property" as="element(property)*"/>
        <xsl:variable name="copyFrom" select="$parentID"/>
        <xsl:variable name="parentRef">
            <xsl:choose>
                <xsl:when test="$parent instance of element(class)">
                    <className target="{$parentID}"><xsl:value-of select="$parent/name"/></className>
                </xsl:when>
                <xsl:when test="$parent instance of element(property)">
                    <propName target="{$parentID}"><xsl:value-of select="$parent/name"/></propName>
                </xsl:when>
                <xsl:when test="$parent instance of element(relation)">
                    <relName target="{$parentID}"><xsl:value-of select="$parent/name"/></relName>
                </xsl:when>
                <xsl:otherwise>
                    <ref target="{$parentID}"><xsl:value-of select="$parent/name"/></ref>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:apply-templates>
                <xsl:with-param name="parentProperties" as="element(property)*" select="$parentProperties" tunnel="yes"/>
                <xsl:with-param name="copyTo" select="$id" tunnel="yes"/>
                <xsl:with-param name="copyFrom" select="$parentID" tunnel="yes"/>
                <xsl:with-param name="parentRef" select="$parentRef" tunnel="yes"/>
            </xsl:apply-templates>
            
        </xsl:copy>
    </xsl:template>
    
</xsl:stylesheet>