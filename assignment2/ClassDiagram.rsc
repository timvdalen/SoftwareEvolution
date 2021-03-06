module ClassDiagram

import String;
import Set;
import List;
import Relation;
import lang::java::m3::Core;
import lang::java::jdt::m3::Core;
import lang::java::m3::TypeSymbol;
import TypeSymbolHelpers;
import FlowPropagation;
import lang::ofg::ast::FlowLanguage;
import lang::ofg::ast::Java2OFG;

str settings = "fontname = \"Courier New\"\nfontsize = 10\nsplines=ortho;\nnode [\nfontname = \"Courier New\"\nfontsize = 10\nshape = \"record\"\n]\nedge [\nfontname = \"Courier New\"\nfontsize = 10\n]\n";
str realizations_settings = "edge[arrowhead = \"empty\"; style = \"dashed\"]\n";
str generalizations_settings = "edge[arrowhead = \"empty\"; style= \"solid\"]\n";
str associations_settings = "edge[arrowhead = \"open\"; style = \"solid\"]\n";
str dependencies_settings = "edge[arrowhead = \"open\"; style = \"dashed\"]\n";

/**
 * Turns the String version of a Modifier into a UML string that denotes visibility
 */
str modifier_to_uml(str modifier){
	switch(modifier){
		case "public()": return "+";
		case "private()": return "-";
		case "protected()": return "#";
		case "static()": return "@";
		case "final()": return "!";
		default: return "?";
	}
}

/**
 * Returns a DOT string representation of the fields in the class
 */
str getFields(M3 model, loc class_loc){
	ret = "";
	
	//Get all containments of type field that are associated with the given class location
	set[loc] class_fields_locs = { e | e <- model@containment[class_loc], e.scheme == "java+field"};
	//Grab the types and modifiers associated with the found field locations
	class_fields_types = domainR(model@types, class_fields_locs);
	class_fields_modifiers = domainR(model@modifiers, class_fields_locs);
	
	//Loop through the found field locations
	for(loc field_loc <- class_fields_locs){
		TypeSymbol field_type = toList(class_fields_types[field_loc])[0];
		
		list[Modifier] field_modifiers = toList(class_fields_modifiers[field_loc]);
		str field_modifier_str = "";
		for(Modifier field_modifier <- field_modifiers){
			field_modifier_str += modifier_to_uml("<field_modifier>");
		}
		
		//I really need casting here, this is beyond horrible
		str field_name = getOneFrom(invert(model@names)[field_loc]);
		str field_return = toString(field_type, model);
		
		ret += "<field_modifier_str> <field_name>: <field_return>\\l";
	}
	return ret;
}

/**
 * Returns a DOT string representation of the methods in the class
 */
str getMethods(M3 model, loc class_loc){
	ret = "";
	
	//Get all containments of type method and constructor that are associated with the given class location
	set[loc] class_methods_locs = { e | e <- model@containment[class_loc], e.scheme == "java+method" || e.scheme == "java+constructor"};
	//Grab the types and modifiers associated with the found field locations
	class_methods_types = domainR(model@types, class_methods_locs);
	class_methods_modifiers = domainR(model@modifiers, class_methods_locs);
	
	//Loop through the found method locations
	for(loc method_loc <- class_methods_locs){
		//Get the TypeSymbol for this location
		TypeSymbol method_type = toList(class_methods_types[method_loc])[0];
		
		//Find the modifiers and turn them into a UML representation
		list[Modifier] method_modifiers = toList(class_methods_modifiers[method_loc]);
		str method_modifier_str = "";
		for(Modifier method_modifier <- method_modifiers){
			//TODO: There should be some sort of more elagant way to get the modifier
			method_modifier_str += modifier_to_uml("<method_modifier>");
		}
		
		//Build the parameters string
		str method_name = getOneFrom(invert(model@names)[method_loc]);
		list[loc] method_params = [e | e <- model@containment[method_loc], e.scheme == "java+parameter"];
		str method_params_str = "";
		for(loc method_param <- method_params){
			TypeSymbol param_type = toList(model@types[method_param])[0];
			str param_name = getOneFrom(invert(model@names)[method_param]);
			
			method_params_str += "<param_name>: <toString(param_type, model)>, ";
		}
		if(size(method_params_str) > 0){
			method_params_str = substring(method_params_str, 0, size(method_params_str) - 2);
		}
		
		//Finally, output the method/constructor
		if(method(l, _, return_type, _) := method_type){
			ret += "<method_modifier_str> <method_name>(<method_params_str>): <toString(return_type, model)>\\l";			
		}else if(constructor(l, _) := method_type){
			ret += "<method_modifier_str> <method_name>(<method_params_str>)\\l";	
		}
	}
	return ret;
}

/**
 * Returns a DOT string representation of the given class
 */
str getClass(M3 model, loc class){
	str ret = "";
	//Note: I'm very much assuming that loc is actually a class here
	str classname = getOneFrom(invert(model@names)[class]);
	TypeSymbol class_type = getOneFrom(model@types[class]);
	str class_type_str = toString(class_type, model);
	ret += "<classname> [\n";
	ret += "label = \"{<class_type_str>|";
	ret += getFields(model, class);
	ret += "|";
	ret += getMethods(model, class);
	ret += "}\"\n";
	ret += "]\n";
	
	return ret;
}

/**
 * Returns a DOT string representation of all the classes inside the model
 */
str getClasses(M3 model){
	str ret = "";
	
	list[loc] mod_classes = toList(classes(model));
	for(loc mod_class <- mod_classes){
		ret += getClass(model, mod_class);
	}
	
	return ret;
}

/**
 * Checks if an element is a part of the project
 */
bool isPartOfProject(M3 model, str element){
	return element in {n | <n,l> <- model@names, l in classes(model)};
}

/**
 * Returns a DOT string representation of the Depends relations in the model
 */
str getDepends(M3 model){
	set[tuple[str,str]] dependencies = {};
	
	for(tuple[loc,loc] depends <- model@methodInvocation){
		str path_a = substring(depends[0].uri, findFirst(depends[0].uri, ":///") + 4);
		str class_a = substring(path_a, 0, findFirst(path_a, "/"));
		str path_b = substring(depends[1].uri, findFirst(depends[1].uri, ":///") + 4);
		str element_b = substring(path_b, 0, findFirst(path_b, "/"));
		
		if(class_a != element_b && isPartOfProject(model, element_b)){
			dependencies += <class_a, element_b>;
		}
	}
	
	str ret = "";
	ret += "edge[arrowhead = \"open\"; style = \"dashed\"]\n";
	for(dependency <- dependencies){
		ret += "<dependency[0]> -\> <dependency[1]>;\n";
	}
	return ret;
}


/**
 * Returns a DOT string representation of the given Relation
 */
str relToString(rel[loc,loc] relation, M3 model){
	str ret = "";
	for(tuple[loc,loc] pair <- relation){
		str class_a = getOneFrom(invert(model@names)[pair[0]]);
		str class_b = getOneFrom(invert(model@names)[pair[1]]);
		ret += "<class_a> -\> <class_b>;\n";
	}
	return ret;
}

/**
 * Returns a DOT string representation of the following relations in de model:
 *    - Realization
 *    - Generalization
 *    - Association
 *    - Dependency
 */
str getRelations(M3 model, loc location){
	str ret = "";
	
	Program p = createOFG(location);
	tuple[rel[loc,loc] ass, rel[loc,loc] deps] output = getOutput(model, p);
	
	rel[loc,loc] realizations = model@implements;
	rel[loc,loc] generalizations = model@extends;
	rel[loc,loc] associations = output.ass - realizations - generalizations;
	rel[loc,loc] dependencies = output.deps - associations - realizations - generalizations;
	
	ret += realizations_settings;
	ret += relToString(realizations, model);
	
	ret += generalizations_settings;
	ret += relToString(generalizations, model);
	
	ret += associations_settings;
	ret += relToString(associations, model);
	
	ret += dependencies_settings;
	ret += relToString(dependencies, model);
	
	return ret;
}

/**
 * Returns a DOT digraph containing a UML class diagram of the given location (must be an Eclipse project)
 *
 * The diagram includes
 * - Classes
 * - Fields
 * - Methods
 */
public str getDot(loc location){
	model = createM3FromEclipseProject(location);
	str ret = "digraph classes{\n";
	ret += settings;
	ret += getClasses(model);
	ret += getRelations(model, location);
	ret += "}";
	return ret;
}
