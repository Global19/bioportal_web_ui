module ResourcesHelper
  
  def generate_details_link(ontology_id, resource, element, concept)
    ontology = DataAccess.getOntology(ontology_id)
    conceptid = ontology.is_latest? ? "#{ontology.ontologyId}/#{concept}&virtual=true" : "#{ontology.id}/#{concept}"
    return "http://keg.cs.uvic.ca/seanf/BioportalTest/get_resource_element_context.php?resourceId=#{resource}&elementId=#{element}&conceptIds=#{conceptid}"
  end
  
end
