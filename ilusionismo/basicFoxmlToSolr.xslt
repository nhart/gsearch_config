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
            <xsl:when test="starts-with($PID, 'magia')">
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
                      <field name="error_s"><xsl:text>What kinda state is this!?</xsl:text></field>
                  </xsl:otherwise>
                </xsl:choose>
              </doc>
            </xsl:when>
          </xsl:choose>
        </xsl:if>
      </xsl:if>
    </add>
  </xsl:template>
  
  <xsl:template match="/foxml:digitalObject" mode="activeFedoraObject">
  
  <xsl:param name="PID"/>

    <field name="PID">
      <xsl:value-of select="$PID"/>
    </field>

    <field name="PID_mlt">
      <xsl:value-of select="$PID"/>
    </field>
    

    <!-- index DC -->
    <xsl:apply-templates mode="simple_set" select="foxml:datastream/foxml:datastreamVersion[last()]/foxml:xmlContent/oai_dc:dc/*">
      <xsl:with-param name="prefix">dc.</xsl:with-param>
      <xsl:with-param name="suffix"></xsl:with-param>
    </xsl:apply-templates>

    <!-- Index the Rels-ext (using match="rdf:RDF") -->
    <xsl:apply-templates select="foxml:datastream[@ID='RELS-EXT']/foxml:datastreamVersion[last()]/foxml:xmlContent/rdf:RDF">
      <xsl:with-param name="prefix">rels_</xsl:with-param>
      <xsl:with-param name="suffix"></xsl:with-param>
    </xsl:apply-templates>
	
    <!-- EAC-CPF -->
    <!-- Name and Surname -->
    <xsl:apply-templates mode="simple_set" select="foxml:datastream/foxml:datastreamVersion[last()]/foxml:xmlContent/eaccpf:eac-cpf/eaccpf:cpfDescription/eaccpf:identity/eaccpf:nameEntry/eaccpf:part[@localType='surname']">
      <xsl:with-param name="prefix">eac-cpf_surname_</xsl:with-param>
      <xsl:with-param name="suffix"></xsl:with-param>
    </xsl:apply-templates>
    
    <xsl:apply-templates mode="simple_set" select="foxml:datastream/foxml:datastreamVersion[last()]/foxml:xmlContent/eaccpf:eac-cpf/eaccpf:cpfDescription/eaccpf:identity/eaccpf:nameEntry/eaccpf:part[@localType='name']">
      <xsl:with-param name="prefix">eac-cpf_name_</xsl:with-param>
      <xsl:with-param name="suffix"></xsl:with-param>
    </xsl:apply-templates>
    
    <!-- Dates -->
    <xsl:apply-templates mode="simple_set_att" select="foxml:datastream/foxml:datastreamVersion[last()]/foxml:xmlContent/eaccpf:eac-cpf/eaccpf:cpfDescription/eaccpf:description/eaccpf:existDates/eaccpf:dateRange/eaccpf:fromDate">
      <xsl:with-param name="prefix">eac-cpf_datefrom_</xsl:with-param>
      <xsl:with-param name="suffix"></xsl:with-param>
    </xsl:apply-templates>
    <xsl:apply-templates mode="simple_set_att" select="foxml:datastream/foxml:datastreamVersion[last()]/foxml:xmlContent/eaccpf:eac-cpf/eaccpf:cpfDescription/eaccpf:description/eaccpf:existDates/eaccpf:dateRange/eaccpf:toDate">
      <xsl:with-param name="prefix">eac-cpf_dateto_</xsl:with-param>
      <xsl:with-param name="suffix"></xsl:with-param>
    </xsl:apply-templates>

  
    <!-- PDF Size -->
		<xsl:variable name="pdf_size" select="foxml:datastream[@ID='PDF']/foxml:datastreamVersion[last()]/@SIZE"/> 
	<xsl:if test="$pdf_size"> 
	  <field name="pdf_size_s"> 
	 		<xsl:value-of select="$pdf_size"/> 
	 	</field> 
	</xsl:if> 
	
    <!-- OCR -->
    <xsl:for-each select="foxml:datastream[@ID='OCR']/foxml:datastreamVersion[last()]">
      <field>
        <xsl:attribute name="name">OCR</xsl:attribute>
        <xsl:value-of select="exts:getDatastreamText($PID, $REPOSITORYNAME, 'OCR', $FEDORASOAP, $FEDORAUSER, $FEDORAPASS, $TRUSTSTOREPATH, $TRUSTSTOREPASS)"/>
        <xsl:message><xsl:value-of select="exts:getDatastreamText($PID, $REPOSITORYNAME, 'OCR', $FEDORASOAP, $FEDORAUSER, $FEDORAPASS, $TRUSTSTOREPATH, $TRUSTSTOREPASS)"/></xsl:message>
        <!-- <xsl:value-of select="islandora-exts:getDatastreamTextRaw($PID, $REPOSITORYNAME, 'OCR', $FEDORASOAP, $FEDORAUSER, $FEDORAPASS, $TRUSTSTOREPATH, $TRUSTSTOREPASS)"/> -->
      </field>
    </xsl:for-each>
	
    
     <!-- MODS -->
      <!-- Title -->
    <xsl:apply-templates mode="simple_set" select="foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]/foxml:xmlContent//mods:mods/mods:titleInfo[not(@type)]/mods:title">
      <xsl:with-param name="prefix">mods_</xsl:with-param>
      <xsl:with-param name="suffix">_b</xsl:with-param>
    </xsl:apply-templates>
    
    <xsl:apply-templates mode="simple_set" select="foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]/foxml:xmlContent//mods:mods/mods:titleInfo[@type='uniform']/mods:title">
      <xsl:with-param name="prefix">mods_uniform_</xsl:with-param>
      <xsl:with-param name="suffix">_b</xsl:with-param>
    </xsl:apply-templates>

    <xsl:apply-templates mode="simple_set" select=
	"foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]/foxml:xmlContent//mods:mods/mods:titleInfo[not(@type)]/mods:subTitle">
      <xsl:with-param name="prefix">mods_</xsl:with-param>
      <xsl:with-param name="suffix">_b</xsl:with-param>
    </xsl:apply-templates>

	    <xsl:apply-templates mode="simple_set" select="foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]/foxml:xmlContent//mods:mods/mods:titleInfo[not(@type)]/mods:partName">
      <xsl:with-param name="prefix">mods_</xsl:with-param>
      <xsl:with-param name="suffix">_b</xsl:with-param>
    </xsl:apply-templates>

    <!-- Names -->
	
    <xsl:apply-templates mode="mods_name" select="foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]/foxml:xmlContent//mods:mods/mods:name">
      <xsl:with-param name="prefix">mods_</xsl:with-param>
      <xsl:with-param name="suffix">_b</xsl:with-param>
    </xsl:apply-templates>
	
    <!-- OriginInfo -->
    <xsl:apply-templates mode="simple_set" select="foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]/foxml:xmlContent//mods:mods/mods:originInfo/mods:place/mods:placeTerm[@type='text']">
      <xsl:with-param name="prefix">mods_</xsl:with-param>
      <xsl:with-param name="suffix"></xsl:with-param>
    </xsl:apply-templates>
    
    <xsl:apply-templates mode="simple_set" select="foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]/foxml:xmlContent//mods:mods/mods:originInfo/mods:publisher">
      <xsl:with-param name="prefix">mods_</xsl:with-param>
      <xsl:with-param name="suffix"></xsl:with-param>
    </xsl:apply-templates>
    
    <xsl:apply-templates mode="simple_set" select="foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]/foxml:xmlContent//mods:mods/mods:originInfo/mods:dateIssued[@encoding='marc']">
      <xsl:with-param name="prefix">mods_</xsl:with-param>
      <xsl:with-param name="suffix">_b</xsl:with-param>
    </xsl:apply-templates>
    
    <!-- Extent -->
    <xsl:apply-templates mode="simple_set" select="foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]/foxml:xmlContent//mods:mods/mods:physicalDescription/mods:extent">
      <xsl:with-param name="prefix">mods_</xsl:with-param>
      <xsl:with-param name="suffix"></xsl:with-param>
    </xsl:apply-templates>
    
    <!-- Language -->
    <xsl:apply-templates mode="simple_set" select="foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]/foxml:xmlContent//mods:mods/mods:note[@type='language']">
      <xsl:with-param name="prefix">mods_</xsl:with-param>
      <xsl:with-param name="suffix">_b</xsl:with-param>
    </xsl:apply-templates>

    <xsl:apply-templates mode="simple_set" select="foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]/foxml:xmlContent//mods:mods/mods:language/mods:languageTerm">
	  <xsl:with-param name="prefix">mods_</xsl:with-param>
      <xsl:with-param name="suffix">_b</xsl:with-param>
    </xsl:apply-templates>

    
    <!-- ToC -->
    <xsl:apply-templates mode="simple_set" select="foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]/foxml:xmlContent//mods:mods/mods:tableOfContents">
      <xsl:with-param name="prefix">mods_</xsl:with-param>
      <xsl:with-param name="suffix">_b</xsl:with-param>
    </xsl:apply-templates>
    
    <!-- Venue -->
    <xsl:apply-templates mode="simple_set" select="foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]/foxml:xmlContent//mods:mods/mods:note[@type='venue']">
      <xsl:with-param name="prefix">mods_venue_</xsl:with-param>
      <xsl:with-param name="suffix"></xsl:with-param>
    </xsl:apply-templates>
    
    <!-- 991 -->
    <xsl:apply-templates mode="simple_set" select="foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]/foxml:xmlContent//mods:mods/mods:note[@type='991']">
      <xsl:with-param name="prefix">mods_991_</xsl:with-param>
      <xsl:with-param name="suffix"></xsl:with-param>
    </xsl:apply-templates>
    
    <!-- Subjects -->
    <xsl:apply-templates mode="simple_set" select="foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]/foxml:xmlContent//mods:mods/mods:subject/mods:topic">
      <xsl:with-param name="prefix">mods_</xsl:with-param>
      <xsl:with-param name="suffix"></xsl:with-param>
    </xsl:apply-templates>
    
    <xsl:apply-templates mode="simple_set" select="foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]/foxml:xmlContent//mods:mods/mods:subject/mods:temporal">
      <xsl:with-param name="prefix">mods_</xsl:with-param>
      <xsl:with-param name="suffix"></xsl:with-param>
    </xsl:apply-templates>
	
	 <!-- ISBN -->
    <xsl:apply-templates mode="simple_set" select="foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]/foxml:xmlContent//mods:mods/mods:identifier">
      <xsl:with-param name="prefix">mods_</xsl:with-param>
      <xsl:with-param name="suffix"></xsl:with-param>
    </xsl:apply-templates>
    
	 <!-- Genre -->
    <xsl:apply-templates mode="simple_set" select="foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]/foxml:xmlContent//mods:mods/mods:genre">
      <xsl:with-param name="prefix">mods_</xsl:with-param>
      <xsl:with-param name="suffix"></xsl:with-param>
    </xsl:apply-templates>

	<!-- Signatura -->
    <xsl:apply-templates mode="simple_set" select="foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]/foxml:xmlContent//mods:mods/mods:location/mods:shelfLocation">
      <xsl:with-param name="prefix">mods_</xsl:with-param>
      <xsl:with-param name="suffix"></xsl:with-param>
    </xsl:apply-templates>

	
     <!-- Show datastreams-->	
    <xsl:for-each select="foxml:datastream[@ID][foxml:datastreamVersion[last()]]">
        <xsl:choose>
          <!-- Don't bother showing some... -->
          <xsl:when test="@ID='DC'"></xsl:when>
		  <xsl:when test="@ID='AUDIT'"></xsl:when>
          <xsl:otherwise>
            <field name="fedora_datastreams_ms">
              <xsl:value-of select="@ID"/>
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
  
  <xsl:template match="foxml:property">
    <xsl:param name="prefix">fgs_</xsl:param>
    <xsl:param name="suffix">_s</xsl:param>
    <xsl:param name="date_suffix">_dt</xsl:param>
    
    <xsl:variable name="name" select="substring-after(@NAME,'#')"/>
    
    <field>
      <xsl:attribute name="name">
        <xsl:value-of select="concat($prefix, $name, $suffix)"/>
      </xsl:attribute>
      <xsl:value-of select="@VALUE"/>
    </field>
    
    <xsl:if test="$name='lastModifiedDate' or $name='createdDate'">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, $name, $date_suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="@VALUE"/>
      </field>
    </xsl:if>
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

  <!-- Basic EAC-CPF -->
  <xsl:template match="eaccpf:eac-cpf">
        <xsl:param name="pid"/>
        <xsl:param name="dsid" select="'EAC-CPF'"/>
        <xsl:param name="prefix" select="'eaccpf_'"/>
        <xsl:param name="suffix" select="'_et'"/> <!-- 'edged' (edge n-gram) text, for auto-completion -->

        <xsl:variable name="cpfDesc" select="eaccpf:cpfDescription"/>
        <xsl:variable name="identity" select="$cpfDesc/eaccpf:identity"/>
        <xsl:variable name="name_prefix" select="concat($prefix, 'name_')"/>
        <!-- ensure that the primary is first -->
        <xsl:apply-templates select="$identity/eaccpf:nameEntry[@localType='primary']">
            <xsl:with-param name="pid" select="$pid"/>
            <xsl:with-param name="prefix" select="$name_prefix"/>
            <xsl:with-param name="suffix" select="$suffix"/>
        </xsl:apply-templates>

        <!-- place alternates (non-primaries) later -->
        <xsl:apply-templates select="$identity/eaccpf:nameEntry[not(@localType='primary')]">
            <xsl:with-param name="pid" select="$pid"/>
            <xsl:with-param name="prefix" select="$name_prefix"/>
            <xsl:with-param name="suffix" select="$suffix"/>
        </xsl:apply-templates>
    </xsl:template>

  <xsl:template match="eaccpf:nameEntry">
    <xsl:param name="pid"/>
    <xsl:param name="prefix">eaccpf_name_</xsl:param>
    <xsl:param name="suffix">_et</xsl:param>

    <!-- fore/first name -->
    <field>
      <xsl:attribute name="name">
        <xsl:value-of select="concat($prefix, 'given', $suffix)"/>
      </xsl:attribute>
      <xsl:choose>
        <xsl:when test="part[@localType='middle']">
          <xsl:value-of select="normalize-space(concat(eaccpf:part[@localType='forename'], ' ', eaccpf:part[@localType='middle']))"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="normalize-space(eaccpf:part[@localType='forename'])"/>
        </xsl:otherwise>
      </xsl:choose>
    </field>
    
    <!-- sur/last name -->
    <field>
      <xsl:attribute name="name">
        <xsl:value-of select="concat($prefix, 'family', $suffix)"/>
      </xsl:attribute>
      <xsl:value-of select="normalize-space(eaccpf:part[@localType='surname'])"/>
    </field>
    
    <!-- id -->
    <field>
      <xsl:attribute name="name">
        <xsl:value-of select="concat($prefix, 'id', $suffix)"/>
      </xsl:attribute>
      <xsl:choose>
        <xsl:when test="@id">
          <xsl:value-of select="concat($pid, '/', @id)"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="concat($pid,'/name_position:', position())"/>
        </xsl:otherwise>
      </xsl:choose>
    </field>

    <!-- full/complete name -->
    <xsl:variable name="full_name">
      <xsl:choose>
        <xsl:when test="normalize-space(part[@localType='middle'])">
          <xsl:value-of select="normalize-space(concat(eaccpf:part[@localType='surname'], ', ', eaccpf:part[@localType='forename'], ' ', eaccpf:part[@localType='middle']))"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="normalize-space(concat(eaccpf:part[@localType='surname'], ', ', eaccpf:part[@localType='forename']))"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    
    <field>
      <xsl:attribute name="name">
        <xsl:value-of select="concat($prefix, 'complete', $suffix)"/>
      </xsl:attribute>
      <xsl:value-of select="$full_name"/>
    </field>
    
    <!-- create sortable copy -->
    <xsl:if test="@localType='primary'">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'complete', '_es')"/>
        </xsl:attribute>
        <xsl:value-of select="$full_name"/>
      </field>
    </xsl:if>
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
  
  <!-- Fighting with NAMES -->
  
  <xsl:template match="*" mode="mods_name">
    <xsl:param name="prefix">mods_</xsl:param>
    <xsl:param name="suffix">_ms</xsl:param>
    
    <xsl:variable name="role" select="normalize-space(mods:role/mods:roleTerm/text())"/>
    <xsl:variable name="spec">
      <xsl:choose>
        <xsl:when test="$role">
          <xsl:value-of select="concat('_', $role)"/>
        </xsl:when>
        <xsl:when test="@usage and @type">
          <xsl:value-of select="concat('_', @usage, '_', @type)"/>
        </xsl:when>
        <xsl:when test="@usage">
          <xsl:value-of select="concat('_', @usage)"/>
        </xsl:when>
        <xsl:when test="@type">
          <xsl:value-of select="concat('_', @type)"/>
        </xsl:when>
      </xsl:choose>
    </xsl:variable>
    
    <field>
      <xsl:attribute name="name">
        <xsl:value-of select="concat($prefix, 'name', $spec, $suffix)"/>
      </xsl:attribute>
      
      <xsl:call-template name="name_parts_given_first">
        <xsl:with-param name="node" select="current()"/>
      </xsl:call-template>
    </field>
    
    
  </xsl:template>
  <xsl:template name="name_parts_given_first">
    <xsl:param name="node"/>
    
    <!--  given name -->
    <xsl:for-each select="$node/mods:namePart[@type='given']">
      <xsl:variable name="text_value" select="normalize-space(text())"/>
      <xsl:if test="$text_value">
        <xsl:value-of select="$text_value"/>
        
        <!--  use as an initial -->
        <xsl:if test="string-length($text_value)=1">
          <xsl:text>.</xsl:text>
        </xsl:if>
        <xsl:text> </xsl:text>
      </xsl:if>
    </xsl:for-each>
    
    <xsl:for-each select="$node/mods:namePart[@type='family']">
      <xsl:variable name="text_value" select="normalize-space(text())"/>
      <xsl:if test="$text_value">
        <xsl:value-of select="$text_value"/>
        <xsl:if test="position()!=last()">
          <xsl:text> </xsl:text>
        </xsl:if>
      </xsl:if>
    </xsl:for-each>
    
    <!-- Other parts -->
    <xsl:for-each select="$node/mods:namePart[not(@type='given' or @type='family')]">
      <xsl:variable name="text_value" select="normalize-space(text())"/>
      <xsl:if test="$text_value">
        <xsl:value-of select="$text_value"/>
        <xsl:if test="position()!=last()">
          <xsl:text> </xsl:text>
        </xsl:if>
      </xsl:if>
    </xsl:for-each>
  </xsl:template>
  
  <xsl:template name="name_parts_given_last">
    <xsl:param name="node"/>
    
    <xsl:for-each select="$node/mods:namePart[@type='family']">
      <xsl:variable name="text_value" select="normalize-space(text())"/>
      <xsl:if test="$text_value">
        <xsl:value-of select="$text_value"/>
        <xsl:choose>
          <xsl:when test="position()!=last()">
            <xsl:text> </xsl:text>
          </xsl:when>
          <xsl:when test="position()=last() and $node/mods:namePart[not(@type='family')]">
            <xsl:text>, </xsl:text>
          </xsl:when>
        </xsl:choose>
      </xsl:if>
    </xsl:for-each>
    
    <xsl:for-each select="$node/mods:namePart[@type='given']">
      <xsl:variable name="text_value" select="normalize-space(text())"/>
      <xsl:if test="$text_value">
        <xsl:value-of select="$text_value"/>
        <xsl:if test="string-length($text_value)=1">
          <xsl:text>.</xsl:text>
        </xsl:if>
        <xsl:choose>
          <xsl:when test="position()!=last()">
            <xsl:text> </xsl:text>
          </xsl:when>
          <xsl:when test="position()=last() and $node/mods:namePart[not(@type='family' or @type='given')]">
            <xsl:text>, </xsl:text>
          </xsl:when>
        </xsl:choose>
      </xsl:if>
    </xsl:for-each>
    
    <xsl:for-each select="$node/mods:namePart[not(@type='family' or @type='given')]">
      <xsl:variable name="text_value" select="normalize-space(text())"/>
      <xsl:if test="$text_value">
        <xsl:value-of select="normalize-space(text())"/>
        <xsl:if test="position()!=last()">
          <xsl:text> </xsl:text>
        </xsl:if>
      </xsl:if>
    </xsl:for-each>
  </xsl:template> 
</xsl:stylesheet>
