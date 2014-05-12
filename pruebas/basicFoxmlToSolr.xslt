<?xml version="1.0" encoding="UTF-8"?>
<!-- $Id: demoFoxmlToLucene.xslt 5734 2006-11-28 11:20:15Z gertsp $ -->
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:exts="xalan://dk.defxws.fedoragsearch.server.GenericOperationsImpl"
    xmlns:islandora-exts="xalan://ca.upei.roblib.DataStreamForXSLT"
    exclude-result-prefixes="exts"
    xmlns:zs="http://www.loc.gov/zing/srw/"
    xmlns:foxml="info:fedora/fedora-system:def/foxml#"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/"
    xmlns:mods="http://www.loc.gov/mods/v3"
    xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
    xmlns:fedora="info:fedora/fedora-system:def/relations-external#"
    xmlns:rel="info:fedora/fedora-system:def/relations-external#"
    xmlns:dwc="http://rs.tdwg.org/dwc/xsd/simpledarwincore/"
    xmlns:fedora-model="info:fedora/fedora-system:def/model#"
    xmlns:uvalibdesc="http://dl.lib.virginia.edu/bin/dtd/descmeta/descmeta.dtd"
    xmlns:uvalibadmin="http://dl.lib.virginia.edu/bin/admin/admin.dtd/"
    xmlns:eaccpf="urn:isbn:1-931666-33-4"
    xmlns:res="http://www.w3.org/2001/sw/DataAccess/rf1/result"
    xmlns:xalan="http://xml.apache.org/xalan"
    xmlns:xlink="http://www.w3.org/1999/xlink">
    <xsl:output method="xml" indent="yes" encoding="UTF-8"/>
    
    <xsl:param name="REPOSITORYNAME" select="repositoryName"/>
    <xsl:param name="FEDORASOAP" select="repositoryName"/>
    <xsl:param name="FEDORAUSER" select="repositoryName"/>
    <xsl:param name="FEDORAPASS" select="repositoryName"/>
    <xsl:param name="TRUSTSTOREPATH" select="repositoryName"/>
    <xsl:param name="TRUSTSTOREPASS" select="repositoryName"/>
    
    <!-- Test of adding explicit parameters to indexing -->
    <xsl:param name="EXPLICITPARAM1" select="defaultvalue1"/>
    <xsl:param name="EXPLICITPARAM2" select="defaultvalue2"/>
    <!--
	 This xslt stylesheet generates the IndexDocument consisting of IndexFields
     from a FOXML record. The IndexFields are:
       - from the root element = PID
       - from foxml:property   = type, state, contentModel, ...
       - from oai_dc:dc        = title, creator, ...
     The IndexDocument element gets a PID attribute, which is mandatory,
     while the PID IndexField is optional.
     Options for tailoring:
       - IndexField types, see Lucene javadoc for Field.Store, Field.Index, Field.TermVector
       - IndexField boosts, see Lucene documentation for explanation
       - IndexDocument boosts, see Lucene documentation for explanation
       - generation of IndexFields from other XML metadata streams than DC
         - e.g. as for uvalibdesc included above and called below, the XML is inline
         - for not inline XML, the datastream may be fetched with the document() function,
           see the example below (however, none of the demo objects can test this)
       - generation of IndexFields from other datastream types than XML
         - from datastream by ID, text fetched, if mimetype can be handled
         - from datastream by sequence of mimetypes,
           text fetched from the first mimetype that can be handled,
           default sequence given in properties.
-->
    
    <xsl:template match="/">
        <xsl:variable name="PID" select="/foxml:digitalObject/@PID"/>
        <add>
            <!-- The following allows only active FedoraObjects to be indexed. -->
            <xsl:if test="foxml:digitalObject/foxml:objectProperties/foxml:property[@NAME='info:fedora/fedora-system:def/model#state']">
                <xsl:if test="not(foxml:digitalObject/foxml:datastream[@ID='METHODMAP' or @ID='DS-COMPOSITE-MODEL'])">
                    <xsl:choose>
                        <!-- avoid indexing stuff with their own cores -->
                        <xsl:when test="starts-with($PID, 'atm')"/>
                        <xsl:when test="starts-with($PID, 'jt')"/>
                        <xsl:when test="starts-with($PID, 'ir')"/>
                        <xsl:when test="starts-with($PID, 'cam')"/>
                        <xsl:when test="starts-with($PID, 'ens')"/>
                        <xsl:when test="starts-with($PID, 'cat')"/>
                        <xsl:otherwise>
                            <doc>
                                <xsl:choose>
                                    <xsl:when test="foxml:digitalObject/foxml:objectProperties/foxml:property[@VALUE='Active']">
                                        <xsl:apply-templates select="/foxml:digitalObject" mode="activeFedoraObject">
                                            <xsl:with-param name="PID" select="$PID"/>
                                        </xsl:apply-templates>
                                    </xsl:when>
                                    <xsl:when test="foxml:digitalObject/foxml:objectProperties/foxml:property[@VALUE='Inactive']">
                                        <xsl:apply-templates select="/foxml:digitalObject" mode="inactiveFedoraObject">
                                            <xsl:with-param name="PID" select="$PID"/>
                                        </xsl:apply-templates>
                                    </xsl:when>
                                    <xsl:when test="foxml:digitalObject/foxml:objectProperties/foxml:property[@VALUE='Deleted']">
                                        <xsl:apply-templates select="/foxml:digitalObject" mode="deletedFedoraObject">
                                            <xsl:with-param name="PID" select="$PID"/>
                                        </xsl:apply-templates>
                                    </xsl:when>
                                    <xsl:otherwise>
                                        <field name="PID"><xsl:value-of select="$PID"/></field>
                                        <field name="error_s"><xsl:text>Estado incorrecto</xsl:text></field>
                                    </xsl:otherwise>
                                </xsl:choose>
                            </doc>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:if>
            </xsl:if>
        </add>
    </xsl:template>
    
    <xsl:template match="/foxml:digitalObject" mode="activeFedoraObject">
        <xsl:param name="PID"/>
        
        <field name="PID" boost="2.5">
            <xsl:value-of select="$PID"/>
        </field>
        
        <xsl:apply-templates select="foxml:objectProperties/foxml:property"/>
        
        <!-- index DC -->
        <xsl:apply-templates mode="simple_set" select="foxml:datastream/foxml:datastreamVersion[last()]/foxml:xmlContent/oai_dc:dc/*">
            <xsl:with-param name="prefix">dc.</xsl:with-param>
            <xsl:with-param name="suffix"></xsl:with-param>
        </xsl:apply-templates>
        
        <!-- Index the Rels-ext (using match="rdf:RDF") -->
        <xsl:apply-templates select="foxml:datastream[@ID='RELS-EXT']/foxml:datastreamVersion[last()]/foxml:xmlContent/rdf:RDF">
            <xsl:with-param name="prefix">rels_</xsl:with-param>
            <xsl:with-param name="suffix">_ms</xsl:with-param>
        </xsl:apply-templates>
        
        <!-- Control de related autors -->
       	<xsl:for-each select="foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]/foxml:xmlContent//mods:mods/mods:name[@type='personal']">
       		<xsl:variable name="rol" select="foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]/foxml:xmlContent//mods:mods/mods:name[@type='personal']/mods:role/mods:roleTerm"/>
			<xsl:variable name="text_value" select="normalize-space(text())"/>
       		<xsl:choose>
       			<xsl:when test="starts-with($rol, 'coaut')">
       				<field name="mods_autor">
       					<xsl:value-of select="namePart" /> ( <xsl:value-of select="$rol" /> )
       				</field>
       			</xsl:when>
       			<xsl:otherwise>
       				<field name="mods_related">
       					<xsl:value-of select="namePart" /> ( <xsl:value-of select="$rol" /> ) <xsl:value-of select="$text_value" />
       				</field>
       			</xsl:otherwise>
       		</xsl:choose>
       	</xsl:for-each>
	
    </xsl:template>
    
    
    <xsl:template match="/foxml:digitalObject" mode="inactiveFedoraObject">
        <xsl:param name="PID"/>
        
        <field name="PID">
            <xsl:value-of select="$PID"/>
        </field>
        <xsl:apply-templates select="foxml:property"/>
    </xsl:template>
    
    <xsl:template match="/foxml:digitalObject" mode="deletedFedoraObject">
        <xsl:param name="PID"/>
        
        <field name="PID">
            <xsl:value-of select="$PID"/>
        </field>
        <xsl:apply-templates select="foxml:property"/>
    </xsl:template>
    
    <xsl:template match="rdf:RDF">
        <xsl:param name="prefix">rels_</xsl:param>
        <xsl:param name="suffix">_s</xsl:param>
        
        <xsl:for-each select=".//rdf:Description/*[@rdf:resource]">
            <field>
                <xsl:attribute name="name">
                    <xsl:value-of select="concat($prefix, local-name(), '_uri', $suffix)"/>
                </xsl:attribute>
                <xsl:value-of select="@rdf:resource"/>
            </field>
        </xsl:for-each>
        <xsl:for-each select=".//rdf:Description/*[not(@rdf:resource)][normalize-space(text())]">
            <field>
                <xsl:attribute name="name">
                    <xsl:value-of select="concat($prefix, local-name(), '_literal', $suffix)"/>
                </xsl:attribute>
                <xsl:value-of select="text()"/>
            </field>
        </xsl:for-each>
    </xsl:template>
    
    <!-- Create fields for the set of selected elements, named according to the 'local-name' and containing the 'text' -->
    <xsl:template match="*" mode="simple_set">
        <xsl:param name="prefix">changeme_</xsl:param>
        <xsl:param name="suffix">_t</xsl:param>
        <field>
            <xsl:attribute name="name">
                <xsl:value-of select="concat($prefix, local-name(), $suffix)"/>
            </xsl:attribute>
            <xsl:value-of select="text()"/>
        </field>
    </xsl:template>
    
</xsl:stylesheet>
