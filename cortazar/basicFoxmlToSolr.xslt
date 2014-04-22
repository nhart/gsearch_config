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
   

  <xsl:param name="REPOSITORYNAME1" select="repositoryName"/>
  <xsl:param name="FEDORASOAP" select="repositoryName"/>
  <xsl:param name="FEDORAUSER" select="repositoryName"/>
  <xsl:param name="FEDORAPASS" select="repositoryName"/>
  <xsl:param name="TRUSTSTOREPATH" select="repositoryName"/>
  <xsl:param name="TRUSTSTOREPASS" select="repositoryName"/>

  <!-- Test of adding explicit parameters to indexing -->
  <xsl:param name="EXPLICITPARAM1" select="defaultvalue1"/>
  <xsl:param name="EXPLICITPARAM2" select="defaultvalue2"/>

  <xsl:template match="/">
    <xsl:variable name="PID" select="/foxml:digitalObject/@PID"/>
    <add>
      <!-- The following allows only active FedoraObjects to be indexed. -->
      <xsl:if test="foxml:digitalObject/foxml:objectProperties/foxml:property[@NAME='info:fedora/fedora-system:def/model#state']">
        <xsl:if test="not(foxml:digitalObject/foxml:datastream[@ID='METHODMAP' or @ID='DS-COMPOSITE-MODEL'])">
           <xsl:if test="starts-with($PID, 'cor')">
             <doc>
               <xsl:apply-templates select="/foxml:digitalObject" mode="activeFedoraObject">
                 <xsl:with-param name="PID" select="$PID"/>
               </xsl:apply-templates>
             </doc>
           </xsl:if>
        </xsl:if>
      </xsl:if>
    </add>
  </xsl:template>
    
	<!-- RELS-EXT -->
  <xsl:template match="rdf:RDF">
    <xsl:param name="prefix">rels-ext_</xsl:param>
    <xsl:param name="suffix">_ms</xsl:param>
    
    <xsl:for-each select=".//rdf:Description/*[not(@rdf:resource)][normalize-space(text())]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, local-name(), '_literal_s', $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="text()"/>
      </field>
    </xsl:for-each>
  </xsl:template>  	
	
	
  <xsl:template name="strip_end">
    <xsl:param name="to_strip">.</xsl:param>
    <xsl:param name="text"/>
    
    <xsl:variable name="to_strip_length" select="string-length($to_strip)"/>
    <xsl:variable name="length" select="string-length($text)"/>
    <xsl:variable name="end" select="$length - $to_strip_length"/>
    <xsl:choose>
      <xsl:when test="$end > 0 and substring($text, $end + 1)=$to_strip">
        <xsl:call-template name="strip_end">
          <xsl:with-param name="to_strip" select="$to_strip"/>
          <xsl:with-param name="text" select="substring($text, 1, $end)"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        
        <xsl:value-of select="$text"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
     
     <!-- Active Fedora Object -->
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
	
	
	<!-- MODS CORTAZAR  --> 

	<!-- autor , personal and corporate
    <xsl:apply-templates mode="simple_set" select="foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]/foxml:xmlContent//mods:mods/mods:name/mods:namePart[not(@type)]">
      <xsl:with-param name="prefix">mods_autor_name_</xsl:with-param>
      <xsl:with-param name="suffix">_s</xsl:with-param>
    </xsl:apply-templates>

    <xsl:apply-templates mode="simple_set" select="foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]/foxml:xmlContent//mods:mods/mods:name[@type='personal' and @usage='primary']/mods:namePart[@type='date']">
      <xsl:with-param name="prefix">mods_autor_date_</xsl:with-param>
      <xsl:with-param name="suffix">_s</xsl:with-param>
    </xsl:apply-templates>
    -->
    <!-- Corrección coautores en MODS-->
	<xsl:apply-templates mode="mods_cortazar" select="foxml:datastream/foxml:datastreamVersion[last()]/foxml:xmlContent//mods:mods/*">
		<xsl:with-param name="prefix">mods_</xsl:with-param>
		<xsl:with-param name="suffix">_s</xsl:with-param>
	</xsl:apply-templates>
	
	<!-- personas relacionadas 
     <xsl:for-each select="foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]/foxml:xmlContent//mods:mods/mods:name[not(@usage)]">
	  <field name="mods_related_s">
        <xsl:value-of select="."/>
      </field>
    </xsl:for-each>
--> 
	 
        
    <!-- Titulo y subtitulo  -->
    
     <!-- <xsl:apply-templates mode="simple_set" select="foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]/foxml:xmlContent//mods:mods/mods:titleInfo[not(@type)]/mods:title">
      <xsl:with-param name="prefix">mods_</xsl:with-param>
      <xsl:with-param name="suffix">_s</xsl:with-param>
    </xsl:apply-templates>

    <xsl:apply-templates mode="simple_set" select="foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]/foxml:xmlContent//mods:mods/mods:titleInfo[not(@type)]/mods:title/mods:subTitle">
      <xsl:with-param name="prefix">mods_</xsl:with-param>
      <xsl:with-param name="suffix">_s</xsl:with-param>
    </xsl:apply-templates>
    
    <xsl:apply-templates mode="simple_set" select="foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]/foxml:xmlContent//mods:mods/mods:titleInfo[not(@type)]/mods:title/mods:nonSort">
      <xsl:with-param name="prefix">mods_</xsl:with-param>
      <xsl:with-param name="suffix">_s</xsl:with-param>
    </xsl:apply-templates> -->
    
	
    <!-- titulo uniforme -->
    <xsl:apply-templates mode="simple_set" select="foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]/foxml:xmlContent//mods:mods/mods:titleInfo[@type='uniform']/mods:title">
      <xsl:with-param name="prefix">mods_uniform_</xsl:with-param>
      <xsl:with-param name="suffix">_s</xsl:with-param>
    </xsl:apply-templates>
    
 
	  
    <!-- país de publicacion -->
    <xsl:apply-templates mode="simple_set" select="foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]/foxml:xmlContent//mods:mods/mods:originInfo/mods:place/mods:placeTerm[@type='code']">
      <xsl:with-param name="prefix">mods_pais_</xsl:with-param>
      <xsl:with-param name="suffix">_s</xsl:with-param>
    </xsl:apply-templates>
    
    
    <!-- idioma -->
    <xsl:apply-templates mode="simple_set" select="foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]/foxml:xmlContent//mods:mods/mods:language[not (@objectPart)]/mods:languageTerm[@type='code']">
      <xsl:with-param name="prefix">mods_</xsl:with-param>
      <xsl:with-param name="suffix">_s</xsl:with-param>
    </xsl:apply-templates>
    
    <!-- Año -->
    <xsl:apply-templates mode="simple_set" select="foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]/foxml:xmlContent//mods:mods/mods:originInfo/mods:edition">
      <xsl:with-param name="prefix">mods_</xsl:with-param>
      <xsl:with-param name="suffix">_s</xsl:with-param>
    </xsl:apply-templates>

	<!-- Edición -->
    <xsl:apply-templates mode="simple_set" select="foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]/foxml:xmlContent//mods:mods/mods:originInfo/mods:dateCreated[@encoding='marc']">
      <xsl:with-param name="prefix">mods_</xsl:with-param>
      <xsl:with-param name="suffix">_s</xsl:with-param>
    </xsl:apply-templates>
    
    <!-- Editorial -->
    <xsl:apply-templates mode="simple_set" select="foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]/foxml:xmlContent//mods:mods/mods:originInfo/mods:publisher">
      <xsl:with-param name="prefix">mods_</xsl:with-param>
      <xsl:with-param name="suffix">_s</xsl:with-param>
    </xsl:apply-templates>
    
    <!--  Ciudad Editorial -->
    <xsl:apply-templates mode="simple_set" select="foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]/foxml:xmlContent//mods:mods/mods:originInfo/mods:place/mods:placeTerm[@type='text']">
      <xsl:with-param name="prefix">mods_ciudad_</xsl:with-param>
      <xsl:with-param name="suffix">_s</xsl:with-param>
    </xsl:apply-templates>
    
    <!--    Fecha de publicación  -->
    <xsl:apply-templates mode="simple_set" select="foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]/foxml:xmlContent//mods:mods/mods:originInfo/mods:dateIssued">
      <xsl:with-param name="prefix">mods_</xsl:with-param>
      <xsl:with-param name="suffix">_s</xsl:with-param>
    </xsl:apply-templates>
    
	 
	<!--    coleccion   --> 
    <xsl:apply-templates mode="simple_set" select="foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]/foxml:xmlContent//mods:mods/mods:relatedItem[@type='series']/mods:titleInfo/mods:title">
      <xsl:with-param name="prefix">mods_colection_</xsl:with-param>
      <xsl:with-param name="suffix">_s</xsl:with-param>
    </xsl:apply-templates>

	
    <!--    ISBN  -->
    <xsl:apply-templates mode="simple_set" select="foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]/foxml:xmlContent//mods:mods/mods:identifier[@type='isbn']">
      <xsl:with-param name="prefix">mods_</xsl:with-param>
      <xsl:with-param name="suffix">_s</xsl:with-param>
    </xsl:apply-templates>
    
    <!--    Paginas e Ilustraciones  -->
    <xsl:apply-templates mode="simple_set" select="foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]/foxml:xmlContent//mods:mods/mods:physicalDescription/mods:extent">
      <xsl:with-param name="prefix">mods_</xsl:with-param>
      <xsl:with-param name="suffix">_s</xsl:with-param>
    </xsl:apply-templates>
    
    <!--    Nota general  -->
    <xsl:for-each select="foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]/foxml:xmlContent//mods:mods/mods:note">
      <xsl:variable name="temp_text">
        <xsl:call-template name="strip_end">
          <xsl:with-param name="to_strip">.</xsl:with-param>
          <xsl:with-param name="text" select="normalize-space(text())"/>
        </xsl:call-template>
      </xsl:variable>
      <xsl:variable name="text_value" select="normalize-space($temp_text)"/>
      <xsl:if test="$text_value">
        <field name="mods_note_s">
          <xsl:value-of select="$text_value"/>
        </field>
      </xsl:if>
    </xsl:for-each>
	
	<!-- Tabla de contenidos -->
	
    <xsl:apply-templates mode="simple_set" select="foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]/foxml:xmlContent//mods:mods/mods:tableOfContents">
      <xsl:with-param name="prefix">mods_</xsl:with-param>
      <xsl:with-param name="suffix">_s</xsl:with-param>
    </xsl:apply-templates>
	
    <!--    Materia texto no controlado 
    <xsl:apply-templates mode="simple_set" select="foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]/foxml:xmlContent//mods:mods/mods:genre">
      <xsl:with-param name="prefix">mods_genre_</xsl:with-param>
      <xsl:with-param name="suffix">_s</xsl:with-param>
    </xsl:apply-templates> -->
	
    <xsl:for-each select="foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]/foxml:xmlContent//mods:mods/mods:genre[not(@authority)]">
      <xsl:variable name="temp_text">
        <xsl:call-template name="strip_end">
          <xsl:with-param name="to_strip">.</xsl:with-param>
          <xsl:with-param name="text" select="normalize-space(text())"/>
        </xsl:call-template>
      </xsl:variable>
      <xsl:variable name="text_value" select="normalize-space($temp_text)"/>
      <xsl:if test="$text_value">
        <field name="mods_genre_s">
          <xsl:value-of select="$text_value"/>
        </field>
      </xsl:if>
    </xsl:for-each>
    
    
    <!--    signatura  -->
    <xsl:apply-templates mode="simple_set" select="foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]/foxml:xmlContent//mods:mods/mods:location/mods:shelfLocation">
      <xsl:with-param name="prefix">mods_</xsl:with-param>
      <xsl:with-param name="suffix">_s</xsl:with-param>
    </xsl:apply-templates>
    
       
    <!--    Materias  
    <xsl:apply-templates mode="simple_set" select="foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]/foxml:xmlContent//mods:mods/mods:subject">
      <xsl:with-param name="prefix">mods_</xsl:with-param>
      <xsl:with-param name="suffix">_s</xsl:with-param>
    </xsl:apply-templates>  
     -->
    
     <!-- Show datastreams-->	
    <xsl:for-each select="foxml:datastream[@ID][foxml:datastreamVersion[last()]]">
        <xsl:choose>
          <!-- Don't bother showing some... -->
          <!-- <xsl:when test="@ID='DC'"></xsl:when> -->
		  <xsl:when test="@ID='AUDIT'"></xsl:when>
          <xsl:otherwise>
            <field name="fedora_datastreams_ms">
              <xsl:value-of select="@ID"/>
            </field>
          </xsl:otherwise>
        </xsl:choose>
    </xsl:for-each>


	
	
  </xsl:template>
  
     <!-- Inactive Fedora Object -->
  <xsl:template match="/foxml:digitalObject" mode="inactiveFedoraObject">
    <xsl:param name="PID"/>
    
    <field name="PID">
      <xsl:value-of select="$PID"/>
    </field>
    <xsl:apply-templates select="foxml:property"/>
  </xsl:template>
  
     <!-- Deleted Fedora Object -->
  <xsl:template match="/foxml:digitalObject" mode="deletedFedoraObject">
    <xsl:param name="PID"/>

    <field name="PID">
      <xsl:value-of select="$PID"/>
    </field>
    <xsl:apply-templates select="foxml:property"/>
  </xsl:template>
  
     <!-- FOXML Properties -->
  <xsl:template match="foxml:property">
    <xsl:param name="prefix">prop_</xsl:param>
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
  
  <xsl:template match="mods:name">
    <xsl:param name="prefix">Fmods_</xsl:param>
    <xsl:param name="suffix"></xsl:param>
    
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
    
	<xsl:for-each select="mods:displayForm">
      <xsl:variable name="text_value" select="normalize-space(text())"/>
      <xsl:if test="$text_value">
        <field>
          <xsl:attribute name="name">
            <xsl:value-of select="concat($prefix, 'name_', $spec, '_', local-name(), $suffix)"/>
          </xsl:attribute>
          <xsl:value-of select="$text_value"/>
        </field>
      </xsl:if>
    </xsl:for-each>
    
    <xsl:variable name="associated_spec">
      <xsl:choose>
        <xsl:when test="@type">
          <xsl:text>_F_</xsl:text>
          <xsl:value-of select="@type"/>
        </xsl:when>
        <xsl:otherwise>
          <!-- nothing doing -->
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
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
  
    <!-- Corrección de coautores y otros problemas en MODS -->
    <xsl:template match="*" mode="mods_cortazar">
        <xsl:variable name="NombreNodo" select="normalize-space(name())"/>
        <xsl:variable name="TipoNodo" select="string(@type)"/>
        <xsl:variable name="Grupo" select="string(@nameTitleGroup)"/>
		<xsl:variable name="Uso" select="string(@usage)"/>
		<xsl:choose>
            <xsl:when test="$NombreNodo='name'">
                <xsl:variable name="autor" select="normalize-space(./mods:namePart)"/>
                <xsl:variable name="rol" select="normalize-space(./mods:role/mods:roleTerm)"/>
                <xsl:variable name="rolcortazar">
				    <xsl:choose>
				        <xsl:when test="$rol = 'trad.'">Julio Cortázar como traductor</xsl:when>
    					<xsl:when test="$rol = 'ed.'">Julio Cortázar como editor</xsl:when>
    					<xsl:when test="$rol = 'autor dedicatoria'">Julio Cortázar como autor de la dedicatoria</xsl:when>
    					<xsl:when test="$rol = 'coord.'">Julio Cortázar como coordinador</xsl:when>
    					<xsl:when test="$rol = 'dir.'">Julio Cortázar como director</xsl:when>
    					<xsl:when test="$rol = 'fot.'">Julio Cortázar como fotógrafo</xsl:when>
    					<xsl:when test="$rol = 'il.'">Julio Cortázar como ilustrador</xsl:when>
    					<xsl:when test="$rol = 'pr.'">Julio Cortázar como prologuista</xsl:when>
    				</xsl:choose>
                </xsl:variable>
                <xsl:choose>
					<xsl:when test="$TipoNodo='personal'">
						<xsl:choose>
							<!-- autores (con tipo 'personal) -->
							<xsl:when test="$Uso='primary'">
								<field name="mods_autor_name_namePart_s">
									<xsl:value-of select="$autor"/>
								</field>
								<field name="mods_autor_s">
									<xsl:value-of select="normalize-space(.)"/>
								</field>

							</xsl:when>
							
							<xsl:otherwise>
								<xsl:choose>
									<!-- los related (con tipo 'personal) con rol de coautores se registran como autores -->
									<xsl:when test="$rol='coaut.'">
										<field name="mods_autor_name_namePart_s">
											<xsl:value-of select="$autor"/>
										</field>
										<field name="mods_autor_s">
											<xsl:value-of select="normalize-space(.)"/>
										</field>
									</xsl:when>

									<xsl:otherwise>
										<xsl:choose>
											<!-- los related (con tipo 'personal) sin rol se registran como autores  -->
											<xsl:when test="$rol=''">
												<field name="mods_autor_name_namePart_s">
													<xsl:value-of select="$autor"/>
												</field>                     
												<field name="mods_autor_s">
													<xsl:value-of select="normalize-space(.)"/>
												</field>
											</xsl:when>
											<xsl:otherwise>
												<xsl:choose>
													<!-- los related (con tipo 'personal) con autor cortazar se registran como cortazar_related-->
													<xsl:when test="$autor='Cortázar, Julio'">
														<field name="mods_cortazar_related_namePart_s">
															<xsl:value-of select="$autor"/>
														</field>                     
														<field name="mods_cortazar_related_s">
															<xsl:value-of select="normalize-space(.)"/>
														</field>												
														<field name="mods_cortazar_related_rol_s">
															<xsl:value-of select="$rolcortazar"/>
														</field>
													</xsl:when>
													<xsl:otherwise>
														<!-- los related (con tipo 'personal) con rol <> coautor se registran como related-->
														<field name="mods_related_namePart_s">
															<xsl:value-of select="$autor"/>
														</field>                     
														<field name="mods_related_s">
															<xsl:value-of select="normalize-space(.)"/>
														</field>												
														<field name="mods_related_rol_s">
															<xsl:value-of select="$autor"/> (<xsl:value-of select="$rol"/>)
														</field>
													</xsl:otherwise>
												</xsl:choose>
											</xsl:otherwise>
										</xsl:choose>
									</xsl:otherwise>           
								</xsl:choose>
							</xsl:otherwise>
						
						</xsl:choose>
                    </xsl:when>
                    <xsl:otherwise>
						<xsl:choose>
							<!-- los related (sin tipo 'personal) con rol de coautores se registran como autores -->
							<xsl:when test="$rol='coaut.'">
								<field name="mods_autor_name_namePart_s">
									<xsl:value-of select="$autor"/>
								</field>
							    <field name="mods_autor_s">
							        <xsl:value-of select="normalize-space(.)"/>
							    </field>
							</xsl:when>
						    <!-- los related -sin tipo 'personal y con nameTitleGroup = 1 (conferencias y corporate primaries)-  se registran como autores -->
						    <xsl:when test="$Grupo='1'">
						        <field name="mods_autor_name_namePart_s">
						            <xsl:value-of select="$autor"/>
						        </field>
						        <field name="mods_autor_s">
						            <xsl:value-of select="normalize-space(.)"/>
						        </field>
						    </xsl:when>
							<xsl:otherwise>
								<xsl:choose>
									<!-- los related (sin tipo 'personal) con autor cortazar se registran como cortazar_related-->
									<xsl:when test="$autor='Cortázar, Julio'">
										<field name="mods_cortazar_related_namePart_s">
											<xsl:value-of select="$autor"/>
										</field>                     
										<field name="mods_cortazar_related_s">
											<xsl:value-of select="normalize-space(.)"/>
										</field>												
										<field name="mods_cortazar_related_rol_s">
											<xsl:value-of select="$rolcortazar"/>
										</field>
									</xsl:when>
									<xsl:otherwise>
										<!-- los related (sin tipo 'personal) con rol <> coautor se registran como related-->
										<field name="mods_related_namePart_s">
											<xsl:value-of select="$autor"/>
										</field>                     
										<field name="mods_related_s">
											<xsl:value-of select="normalize-space(.)"/>
										</field>												
										<field name="mods_related_rol_s">
											<xsl:value-of select="$autor"/> (<xsl:value-of select="$rol"/>)
										</field>
									</xsl:otherwise>
								</xsl:choose>
							</xsl:otherwise>
						</xsl:choose>
					</xsl:otherwise>
				</xsl:choose>
			</xsl:when>	
				
			<xsl:otherwise>
				<xsl:choose>
					<xsl:when test="$NombreNodo='subject'">
							<field name="mods_subject_s">
								<xsl:call-template name='string_builder'>
									<xsl:with-param name='data' select="normalize-space(.)" />
									<xsl:with-param name="separator"> - </xsl:with-param>
								</xsl:call-template>
							</field>
					</xsl:when>
				
					<xsl:otherwise>
					
						<xsl:if test="$NombreNodo='titleInfo'">
							<xsl:choose>
								<xsl:when test="$TipoNodo='uniform'">
									<!-- los procesa arriba -->
								</xsl:when>
								<xsl:otherwise>
									<xsl:variable name="TipoTitle" select="string(@type)"/>
									<xsl:variable name="nonSort" select="normalize-space(./mods:nonSort)"/>		
									<xsl:variable name="title" select="normalize-space(./mods:title)"/>
									<xsl:variable name="subTitle" select="normalize-space(./mods:subTitle)"/>
									<xsl:if test="$TipoTitle!='alternative'">
										<field name="mods_title_full_s">
											<xsl:value-of select="concat($nonSort, ' ', $title,' ', $subTitle)"/>
										</field>
										<field name="mods_title_s">
											<xsl:value-of select="$title"/>
										</field>
										<field name="mods_subtitle_s">
											<xsl:value-of select="$subTitle"/>
										</field>
										<field name="mods_title_nonsort_s">
											<xsl:value-of select="$nonSort"/>
										</field>
									</xsl:if>
								</xsl:otherwise>
							</xsl:choose>
						</xsl:if>	
					</xsl:otherwise>
                </xsl:choose>
            </xsl:otherwise>
        </xsl:choose>   
    </xsl:template>

	<xsl:template name='string_builder'>
        <xsl:param name='data' />
        <xsl:param name='separator' />        
        <xsl:for-each select='*'>
            
                <xsl:value-of select='normalize-space(.)'/>
                <xsl:if test='position() != last()'>
                    <xsl:if test='normalize-space(.)'>
                        <xsl:value-of select='$separator'/>
                    </xsl:if>
                </xsl:if>
        </xsl:for-each>
    </xsl:template>

  
  
  <xsl:template match="*" mode="simple_set_att">
    <xsl:param name="prefix">changeme_</xsl:param>
    <xsl:param name="suffix">_t</xsl:param>
    
    <field>
      <xsl:attribute name="name">
        <xsl:value-of select="concat($prefix, local-name(), $suffix)"/>
      </xsl:attribute>
      <xsl:value-of select="@standardDate"/>
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

    <xsl:for-each select="$node/mods:namePart[@type='date']">
    </xsl:for-each>

    
    <!-- Other parts -->
    <xsl:for-each select="$node/mods:namePart[not(@type='given' or @type='family' or @type='date')]">
      <xsl:variable name="text_value" select="normalize-space(text())"/>
      <xsl:if test="$text_value">
        <xsl:value-of select="$text_value"/>
        <xsl:if test="position()!=last()">
          <xsl:text> </xsl:text>
        </xsl:if>
      </xsl:if>
    </xsl:for-each>
  </xsl:template>

  
</xsl:stylesheet>
