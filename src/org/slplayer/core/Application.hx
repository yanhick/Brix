/*
 * This file is part of SLPlayer http://www.silexlabs.org/groups/labs/slplayer/
 * 
 * This project is © 2011-2012 Silex Labs and is released under the GPL License:
 * 
 * This program is free software; you can redistribute it and/or modify it under the terms 
 * of the GNU General Public License (GPL) as published by the Free Software Foundation; 
 * either version 2 of the License, or (at your option) any later version. 
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; 
 * without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. 
 * See the GNU General Public License for more details.
 * 
 * To read the license please visit http://www.gnu.org/copyleft/gpl.html
 */
package org.slplayer.core;

import js.Lib;
import js.Dom;

import org.slplayer.component.ISLPlayerComponent;

/**
 * The main SLPlayer class handles the application initialization. It instanciates the components, tracking for each of them their 
 * association with their DOM rootElement. This class is based on the content of the application HTML file and is thus associated 
 * with the AppBuilder building macro.
 * 
 * @author Thomas Fétiveau
 */
@:build(org.slplayer.core.Builder.build()) class Application 
{
	/**
	 * The data- attribute set by the slplayer on the HTML elements associated with one or more component.
	 */
	static inline private var SLPID_ATTR_NAME = "slpid";
	
	/**
	 * A Hash of SLPlayer instances indexed by their id.
	 */
	static private var instances : Hash<Application> = new Hash();
	/**
	 * Gets an SLPlayer instance corresponding to an id.
	 */
	static public function get(SLPId:String):Null<Application>
	{
		return instances.get(SLPId);
	}
	
	/**
	 * The SLPlayer instance id.
	 */
	private var id : String;
	/**
	 * A Hash keeping all component instances indexed by node slplayer id.
	 */
	private var nodeToCmpInstances : Hash<List<org.slplayer.component.ui.DisplayObject>>;
	/**
	 * The SLPlayer root application node. Usually, any class used in a SLPlayer application shouldn't use 
	 * Lib.document.body directly but this variable instead.
	 */
	public var htmlRootElement(default,null) : HtmlDom;
	/**
	 * The potential arguments passed to the SLPlayer class at instanciation.
	 */
	public var dataObject(default,null) : Dynamic;
	/**
	 * A collection of the <script> declared components with the optionnal data- args passed on the <script> tag.
	 */
	private var registeredComponents : Array<RegisteredComponent>;
	/**
	 * A collection of name => content <meta> header parameters from the source HTML page.
	 */
	private var metaParameters : Hash<String>;
	
	/**
	 * Gets a meta parameter value.
	 */
	public function getMetaParameter(metaParamKey:String):Null<String>
	{
		return metaParameters.get(metaParamKey);
	}
	
	/**
	 * SLPlayer application constructor.
	 * @param	?args		optional, args of any nature from outside the SLPlayer application.
	 */
	private function new(id:String, ?args:Dynamic) 
	{
		this.dataObject = args;
		
		this.id = id;
		
		this.registeredComponents = new Array();
		
		this.nodeToCmpInstances = new Hash();
		
		this.metaParameters = new Hash();
		
		#if slpdebug
			trace("new SLPlayer instance built");
		#end
	}
	
	/**
	 * Launch the application on a given node.
	 * @param	?appendTo	optional, the parent application's node to which to hook this SLplayer application. By default or if
	 * the given node is invalid, it's the document's body element (or equivalent if not js) that is used for that.
	 */
	private function launch(?appendTo:Null<Dynamic>)
	{
		#if slpdebug
			trace("Launching SLPlayer id "+id+" on "+appendTo);
		#end
		
		if (appendTo != null) //set the SLPlayer application root element
		{
			#if slpdebug
				trace("setting htmlRootElement to "+appendTo);
			#end
			htmlRootElement = cast appendTo;
		}
		
		//it can't be a non element node
		if (htmlRootElement == null || htmlRootElement.nodeType != Lib.document.body.nodeType)
		{
			#if slpdebug
				trace("setting htmlRootElement to Lib.document.body");
			#end
			htmlRootElement = Lib.document.body;
		}
		
		if ( htmlRootElement == null )
		{
			#if js
			trace("ERROR windows.document.body is null => You are trying to start your application while the document loading is probably not complete yet." +
			" To fix that, add the noAutoStart option to your slplayer application and control the application startup with: window.onload = function() { myApplication.init() };");
			#else
			trace("ERROR could not set Application's root element.");
			#end
			//do not continue
			return;
		}
		
		initHtmlRootElementContent();
		
		//build the SLPlayer instance meta parameters Hash
		initMetaParameters();
		
		//register the application components for initialization
		registerComponentsforInit();
		
		//call the UI components init() method
		initComponents();
		
		#if slpdebug
			trace("SLPlayer id "+id+" launched !");
		#end
	}
	
	/**
	 * This function is implemented by the AppBuilder macro
	 */
	private function initHtmlRootElementContent()
	{
		//#if (!js || embedHtml)
		//htmlRootElement.innerHTML = _htmlBody; // this call is added by the macro if needed
		//#end
	}
	
	/**
	 * Generates unique ids for SLPlayer instances and for HTML nodes.
	 * FIXME ? there may be a better way to get a unique id...
	 * @return String, a unique id.
	 */
	static private function generateUniqueId():String
	{
		return haxe.Md5.encode(Date.now().toString()+Std.string(Std.random(Std.int(Date.now().getTime()))));
	}
	
	/**
	 * The main entry point of every SLPlayer application. The implementation of this method is completed by the AppBuilder macro.
	 * @param	?appendTo	optional, the element (HTML DOM in js, Sprite in Flash) to which append the SLPlayer application to.
	 * @param	?args		optional, args of any nature from outside the SLPlayer application.
	 */
	static public function init(?appendTo:Dynamic, ?args:Dynamic )
	{
		#if slpdebug
			trace("SLPlayer init() called with appendTo="+appendTo+" and args="+args);
		#end
		
		//generate a new SLPlayerInstance id
		var newId = generateUniqueId();
		
		#if slpdebug
			trace("New SLPlayer id created : "+newId);
		#end
		
		//the new SLPlayer instance
		var newInstance = new Application(newId, args);
		#if slpdebug
			trace("setting ref to SLPlayer instance "+newId);
		#end
		instances.set(newId, newInstance);
	}
	
	/**
	 * The main entry point in autoStart mode. This function is implemented by the AppBuilder macro.
	 */
	static public function main()
	{
		#if !noAutoStart
		
			#if slpdebug
				trace("noAutoStart not defined: calling init()...");
			#end
			
			init();
		#end
	}
	
	/**
	 * This function is implemented by the AppBuilder macro.
	 */
	private function initMetaParameters() { }
	
	/**
	 * This function is implemented by the AppBuilder macro.
	 */
	private function registerComponentsforInit() { }
	
	private function registerComponent(componentClassName : String , ?args:Hash<String>)
	{
		registeredComponents.push({classname:componentClassName, args:args});
	}

	/**
	 * Initialize the application's components in 2 stages : first create the instances and then call init()
	 * on each DisplayObject component.
	 */
	private function initComponents()
	{
		//Create the components instances
		for (rc in registeredComponents)
		{
			createComponentsOfType(rc.classname, rc.args);
		}
		
		//call init on each component instances
		callInitOnComponents();
	}
	
	/**
	 * This is a kind of factory method for all kinds of components (DisplayObjects and no DisplayObjects).
	 * 
	 * @param	componentClassName the full component class name (with packages, for example : org.slplayer.component.player.ImagePlayer)
	 */
	private function createComponentsOfType(componentClassName : String , ?args:Hash<String>)
	{
		#if slpdebug
			trace("Creating "+componentClassName+"...");
		#end
		
		var componentClass = Type.resolveClass(componentClassName);
		
		if (componentClass == null)
		{
			trace("ERROR cannot resolve "+componentClassName);
			return;
		}
		
		#if slpdebug
			trace(componentClassName+" class resolved ");
		#end
		
		if (org.slplayer.component.ui.DisplayObject.isDisplayObject(componentClass)) // case DisplayObject component
		{
			var classTag = getUnconflictedClassTag(componentClassName );
			
			#if slpdebug
				trace("searching now for class tag = "+classTag);
			#end
			
			var taggedNodes : Array<HtmlDom> = new Array();
			
			var taggedNodesCollection : HtmlCollection<HtmlDom> = untyped htmlRootElement.getElementsByClassName(classTag);
			for (nodeCnt in 0...taggedNodesCollection.length)
			{
				taggedNodes.push(taggedNodesCollection[nodeCnt]);
			}
			if (componentClassName != classTag)
			{
				#if slpdebug
					trace("searching now for class tag = "+componentClassName);
				#end
				
				taggedNodesCollection = untyped htmlRootElement.getElementsByClassName(componentClassName);
				for (nodeCnt in 0...taggedNodesCollection.length)
				{
					taggedNodes.push(taggedNodesCollection[nodeCnt]);
				}
			}
			
			#if slpdebug
				trace("taggedNodes = "+taggedNodes.length);
			#end
			
			for (node in taggedNodes)
			{
				var newDisplayObject;
				
				#if !stopOnError
				try
				{
				#end
					
					newDisplayObject = Type.createInstance( componentClass, [node, id] );
					
					#if slpdebug
						trace("Successfuly created instance of "+componentClassName);
					#end
				
				#if !stopOnError
				}
				catch ( unknown : Dynamic )
				{
					trace("ERROR while creating "+componentClassName+": "+Std.string(unknown));
					var excptArr = haxe.Stack.exceptionStack();
					if ( excptArr.length > 0 )
					{
						trace( haxe.Stack.toString(haxe.Stack.exceptionStack()) );
					}
				}
				#end
			}
		}
		else //case of non-visual component: we just try to create an instance, no call on init()
		{
			#if slpdebug
				trace("Try to create an instance of "+componentClassName+" non visual component");
			#end
			
			var cmpInstance = null;
			
			#if !stopOnError
			try
			{
			#end
			
				if (args != null)
					cmpInstance = Type.createInstance( componentClass, [args] );
				else
					cmpInstance = Type.createInstance( componentClass, [] );
				
				#if slpdebug
					trace("Successfuly created instance of "+componentClassName);
				#end
			
			#if !stopOnError
			}
			catch (unknown : Dynamic )
			{
				trace("ERROR while creating "+componentClassName+": "+Std.string(unknown));
				var excptArr = haxe.Stack.exceptionStack();
				if ( excptArr.length > 0 )
				{
					trace( haxe.Stack.toString(haxe.Stack.exceptionStack()) );
				}
			}
			#end
			
			//if the component is an SLPlayer cmp (and it should be), then try to give him its SLPlayer instance id
			if (cmpInstance != null && Std.is(cmpInstance, ISLPlayerComponent))
			{
				cmpInstance.initSLPlayerComponent(id);
			}
		}
	}
	
	/**
	 * Initializes all registered UI component instances.
	 */
	private function callInitOnComponents():Void
	{
		#if slpdebug
			trace("call Init On Components");
		#end
		
		for (l in nodeToCmpInstances)
		{
			for (c in l)
			{
				#if !stopOnError
				try
				{
				#end
				
					c.init();
				
				#if !stopOnError
				}
				catch (unknown : Dynamic)
				{
					trace("ERROR while trying to call init() on a "+Type.getClassName(Type.getClass(c))+": "+Std.string(unknown));
					var excptArr = haxe.Stack.exceptionStack();
					if ( excptArr.length > 0 )
					{
						trace( haxe.Stack.toString(haxe.Stack.exceptionStack()) );
					}
				}
				#end
			}
		}
	}
	
	/**
	 * Adds a component instance to the list of associated component instances of a given node.
	 * @param	node	the node we want to add an associated component instance to.
	 * @param	cmp		the component instance to add.
	 */
	public function addAssociatedComponent(node : HtmlDom, cmp : org.slplayer.component.ui.DisplayObject) : Void
	{
		var nodeId = node.getAttribute("data-" + SLPID_ATTR_NAME);
		
		var associatedCmps : List<org.slplayer.component.ui.DisplayObject>;
		
		if (nodeId != null)
		{
			associatedCmps = nodeToCmpInstances.get(nodeId);
		}
		else
		{
			nodeId = generateUniqueId();
			node.setAttribute("data-" + SLPID_ATTR_NAME, nodeId);
			associatedCmps = new List();
		}
		
		associatedCmps.add(cmp);
		
		nodeToCmpInstances.set( nodeId, associatedCmps );
	}
	
	/**
	 * Gets the component instance(s) associated with a given node.
	 * @param	node		the HTML node for which we search the associated component instances.
	 * @param	typeFilter	an optionnal type filter (specify here a Type or an Interface, eg : Button, Draggable, List...). 
	 * @return	a List<DisplayObject>, empty if there is no component.
	 */
	public function getAssociatedComponents(node : HtmlDom, ?typeFilter:Dynamic=null) : List<org.slplayer.component.ui.DisplayObject>
	{
		var nodeId = node.getAttribute("data-" + SLPID_ATTR_NAME);
		
		if (nodeId != null)
		{
			if (typeFilter == null)
			{
				return nodeToCmpInstances.get(nodeId);
			}
			else
			{
				var l = new List();
				for (i in nodeToCmpInstances.get(nodeId))
				{
					if (Std.is(i, typeFilter))
						l.add(i);
				}
				return l;
			}
		}
		
		return new List();
	}
	
	/**
	 * Determine a class tag value for a component that won't be conflicting with other components.
	 * 
	 * @param	displayObjectClassName
	 * @return	a tag class value for the given component class name that will not conflict with other components classnames / class tags.
	 */
	public function getUnconflictedClassTag(displayObjectClassName : String) : String
	{
		var classTag = displayObjectClassName;
		
		if (classTag.indexOf(".") != -1)
			classTag = classTag.substr(classTag.lastIndexOf(".") + 1);
		
		for (rc in registeredComponents)
		{
			if (rc.classname != displayObjectClassName && classTag == rc.classname.substr(classTag.lastIndexOf(".") + 1))
			{
				return displayObjectClassName;
			}
		}
		
		return classTag;
	}
}

/**
 * A struct for describing a component declared in the application.
 */
typedef RegisteredComponent = 
{
	var classname : String;
	var args : Null<Hash<String>>;
}