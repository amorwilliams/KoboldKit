//
//  KKTilemapNode.m
//  KoboldKit
//
//  Created by Steffen Itterheim on 18.06.13.
//  Copyright (c) 2013 Steffen Itterheim. All rights reserved.
//

#import "KKTilemapNode.h"
#import "KKTilemapTileLayerNode.h"
#import "KKTilemapObjectLayerNode.h"
#import "KKTilemap.h"
#import "KKTilemapLayer.h"
#import "KKTilemapObject.h"
#import "KKTilemapTileset.h"
#import "KKTilemapProperties.h"
#import "SKNode+KoboldKit.h"
#import "KKFollowTargetBehavior.h"
#import "KKStayInBoundsBehavior.h"
#import "KKIntegerArray.h"
#import "KKMutableNumber.h"
#import "KKView.h"
#import "KKScene.h"
#import "KKModel.h"
#import "KKClassVarSetter.h"


@implementation KKTilemapNode

#pragma mark Init/Setup

+(id) tilemapWithContentsOfFile:(NSString*)tmxFile
{
	return [[self alloc] initWithContentsOfFile:tmxFile];
}

-(id) initWithContentsOfFile:(NSString*)tmxFile
{
	self = [super init];
	if (self)
	{
		self.name = tmxFile;
		_tilemap = [KKTilemap tilemapWithContentsOfFile:tmxFile];
		_tileLayerNodes = [NSMutableArray arrayWithCapacity:2];
		_objectLayerNodes = [NSMutableArray arrayWithCapacity:2];
	}
	return self;
}

-(void) didMoveToParent
{
	if (self.children.count == 0)
	{
		[self observeSceneEvents];
		
		self.scene.backgroundColor = _tilemap.backgroundColor;
		
		KKTilemapTileLayerNode* tileLayerNode = nil;
		
		for (KKTilemapLayer* layer in _tilemap.layers)
		{
			if (layer.isTileLayer)
			{
				tileLayerNode = [KKTilemapTileLayerNode tileLayerNodeWithLayer:layer];
				tileLayerNode.alpha = layer.alpha;
				tileLayerNode.tilemapNode = self;
				[self addChild:tileLayerNode];
				[_tileLayerNodes addObject:tileLayerNode];
			}
			else
			{
				KKTilemapObjectLayerNode* objectLayerNode = [KKTilemapObjectLayerNode objectLayerNodeWithLayer:layer];
				objectLayerNode.zPosition = -1;
				objectLayerNode.tilemapNode = self;
				
				NSAssert1(tileLayerNode, @"can't add object layer '%@' because no tile layer precedes it", layer.name);
				[tileLayerNode addChild:objectLayerNode];
				[_objectLayerNodes addObject:objectLayerNode];
			}
		}
		
		_mainTileLayerNode = [self findMainTileLayerNode];
		_gameObjectsLayerNode = [self findGameObjectsLayerNode];
	}
}

-(void) enableParallaxScrolling
{
	// parallaxing behavior
	KKFollowTargetBehavior* parallaxBehavior = [KKFollowTargetBehavior followTarget:_mainTileLayerNode];
	for (KKTilemapLayerNode* layerNode in _tileLayerNodes)
	{
		if (layerNode != _gameObjectsLayerNode)
		{
			parallaxBehavior.positionMultiplier = layerNode.layer.parallaxFactor;
			[layerNode addBehavior:[parallaxBehavior copy] withKey:NSStringFromClass([KKFollowTargetBehavior class])];
		}
	}
}

-(void) restrictScrollingToMapBoundary
{
	// camera boundary scrolling
	KKTilemapLayer* mainTileLayer = _mainTileLayerNode.layer;
	if (mainTileLayer.endlessScrollingHorizontal == NO || mainTileLayer.endlessScrollingVertical == NO)
	{
		CGRect cameraBounds = self.bounds;
		CGRect sceneFrame = self.scene.frame;
		
		if (mainTileLayer.endlessScrollingHorizontal == NO)
		{
			cameraBounds.origin.x = -cameraBounds.size.width + sceneFrame.origin.x + sceneFrame.size.width;
			cameraBounds.size.width = cameraBounds.size.width - sceneFrame.size.width;
		}
		if (mainTileLayer.endlessScrollingVertical == NO)
		{
			cameraBounds.origin.y = -cameraBounds.size.height + sceneFrame.origin.y + sceneFrame.size.height;
			cameraBounds.size.height = cameraBounds.size.height - sceneFrame.size.height;
		}

		NSLog(@"Tilemap scrolling bounds: %@", NSStringFromCGRect(cameraBounds));
		NSString* const kMapBoundaryBehaviorKey = @"KKTilemapNode:MapBoundaryScrolling";
		if ([_mainTileLayerNode behaviorForKey:kMapBoundaryBehaviorKey] == nil)
		{
			[_mainTileLayerNode addBehavior:[KKStayInBoundsBehavior stayInBounds:cameraBounds] withKey:kMapBoundaryBehaviorKey];
		}
	}
}

#pragma mark Position

-(void) setPosition:(CGPoint)position
{
	[super setPosition:position];
	
	_mainTileLayerNode.position = ccpMult(position, 1);
}

#pragma mark Update

-(void) didSimulatePhysics
{
	for (KKTilemapTileLayerNode* tileLayer in _tileLayerNodes)
	{
		[tileLayer updateLayer];
	}
	
	_tilemap.modified = NO;
}

#pragma mark Main Layer

-(KKTilemapTileLayerNode*) findMainTileLayerNode
{
	KKTilemapTileLayerNode* mainTileLayerNode = [self tileLayerNodeNamed:@"main layer"];
	if (mainTileLayerNode == nil)
	{
		mainTileLayerNode = [self tileLayerNodeNamed:@"mainlayer"];
	}
	
	NSAssert(mainTileLayerNode, @"tile layer named 'main layer' is missing!");
	return mainTileLayerNode;
}

-(KKTilemapObjectLayerNode*) findGameObjectsLayerNode
{
	KKTilemapObjectLayerNode* gameObjectsLayerNode = [self objectLayerNodeNamed:@"game objects"];
	if (gameObjectsLayerNode == nil)
	{
		gameObjectsLayerNode = [self objectLayerNodeNamed:@"gameobjects"];
	}
	
	NSAssert(gameObjectsLayerNode, @"object layer named 'game objects' is missing!");
	return gameObjectsLayerNode;
}

#pragma mark Layers

-(KKTilemapTileLayerNode*) tileLayerNodeNamed:(NSString*)name
{
	for (KKTilemapTileLayerNode* tileLayerNode in _tileLayerNodes)
	{
		if ([tileLayerNode.name isEqualToString:name])
		{
			return tileLayerNode;
		}
	}
	
	return nil;
}

-(KKTilemapObjectLayerNode*) objectLayerNodeNamed:(NSString*)name
{
	for (KKTilemapObjectLayerNode* objectLayerNode in _objectLayerNodes)
	{
		if ([objectLayerNode.name isEqualToString:name])
		{
			return objectLayerNode;
		}
	}
	
	return nil;
}

#pragma mark Collision

-(void) addGidStringComponents:(NSArray*)components toGidArray:(KKIntegerArray*)gidArray gidOffset:(gid_t)gidOffset
{
	for (NSString* range in components)
	{
		NSUInteger gidStart = 0, gidEnd = 0;
		NSArray* fromTo = [range componentsSeparatedByString:@"-"];
		if (fromTo.count == 1)
		{
			gidStart = [[fromTo firstObject] intValue];
			gidEnd = gidStart;
		}
		else
		{
			gidStart = [[fromTo firstObject] intValue];
			gidEnd = [[fromTo lastObject] intValue];
		}
		
		for (NSUInteger i = gidStart; i <= gidEnd; i++)
		{
			[gidArray addInteger:i + gidOffset - 1];
		}
	}
}

-(SKNode*) createPhysicsShapesWithTileLayerNode:(KKTilemapTileLayerNode*)tileLayerNode
{
	KKIntegerArray* nonBlockingGids = [KKIntegerArray integerArrayWithCapacity:32];
	for (KKTilemapTileset* tileset in _tilemap.tilesets)
	{
		id nonBlocking = [tileset.properties.properties objectForKey:@"nonBlockingTiles"];
		if ([nonBlocking isKindOfClass:[KKMutableNumber class]])
		{
			[nonBlockingGids addInteger:[nonBlocking intValue]];
		}
		else if ([nonBlocking isKindOfClass:[NSString class]])
		{
			NSString* nonBlockingTiles = (NSString*)nonBlocking;
			NSAssert([[nonBlockingTiles lowercaseString] isEqualToString:@"all"] == NO, @"the keyword 'all' is not allowed for nonBlockingTiles property");
			if (nonBlockingTiles && nonBlockingTiles.length > 0)
			{
				NSArray* components = [nonBlockingTiles componentsSeparatedByString:@","];
				[self addGidStringComponents:components toGidArray:nonBlockingGids gidOffset:tileset.firstGid];
			}
		}
	}
	
	LOG_EXPR(nonBlockingGids);

	unsigned int nonBlockingGidsCount = nonBlockingGids.count;
	NSUInteger* nonBlockingGidValues = nonBlockingGids.integers;
	
	KKIntegerArray* blockingGids = [KKIntegerArray integerArrayWithCapacity:32];
	for (unsigned int i = 1; i <= _tilemap.highestGid; i++)
	{
		BOOL isBlocking = YES;
		
		for (unsigned int k = 0; k < nonBlockingGidsCount; k++)
		{
			if (i == nonBlockingGidValues[k])
			{
				isBlocking = NO;
				break;
			}
		}
		
		if (isBlocking)
		{
			[blockingGids addInteger:i];
		}
	}
	
	SKNode* containerNode;
	NSArray* contours = [tileLayerNode.layer contourPathsWithBlockingGids:blockingGids];
	if (contours.count)
	{
		containerNode = [SKNode node];
		containerNode.name = [NSString stringWithFormat:@"%@:PhysicsBlockingContainerNode", tileLayerNode.name];
		[tileLayerNode addChild:containerNode];
		
		for (id contour in contours)
		{
			SKNode* bodyNode = [SKNode node];
			[bodyNode physicsBodyWithEdgeLoopFromPath:(__bridge CGPathRef)contour];
			[containerNode addChild:bodyNode];
		}
	}
	
	return containerNode;
}

-(SKNode*) createPhysicsShapesWithObjectLayerNode:(KKTilemapObjectLayerNode*)objectLayerNode
{
	SKNode* containerNode;
	KKTilemapLayer* objectLayer = objectLayerNode.layer;
	NSArray* objectPaths = [objectLayer pathsFromObjects];
	
	if (objectPaths.count)
	{
		containerNode = [SKNode node];
		containerNode.name = [NSString stringWithFormat:@"%@:PhysicsBlockingContainerNode", objectLayerNode.name];
		[_mainTileLayerNode addChild:containerNode];
		
		NSUInteger i = 0;
		for (KKTilemapObject* object in objectLayer.objects)
		{
			id objectPath = [objectPaths objectAtIndex:i++];
			CGPathRef path = (__bridge CGPathRef)objectPath;
			
			SKNode* objectNode = [SKNode node];
			objectNode.position = object.position;
			objectNode.zRotation = object.rotation;
			
			if (CGPathIsRect(path, nil))
			{
				[objectNode physicsBodyWithEdgeLoopFromPath:path];
			}
			else
			{
				[objectNode physicsBodyWithEdgeChainFromPath:path];
			}
			[containerNode addChild:objectNode];
		}
	}

	return containerNode;
}

#pragma mark Spawn Objects

-(void) spawnObjects
{
	for (KKTilemapObjectLayerNode* objectLayerNode in _objectLayerNodes)
	{
		[self spawnObjectsWithLayerNode:objectLayerNode];
	}
}

-(void) spawnObjectsWithLayerNode:(KKTilemapObjectLayerNode*)objectLayerNode
{
	NSMutableDictionary* varSetterCache = [NSMutableDictionary dictionaryWithCapacity:4];
	[varSetterCache setObject:[[KKClassVarSetter alloc] initWithClass:NSClassFromString(@"PKPhysicsBody")] forKey:@"PKPhysicsBody"];
	
	NSDictionary* objectTemplates = [objectLayerNode.kkScene.kkView.model objectForKey:@"objectTemplates"];
	NSAssert(objectTemplates, @"view's objectTemplates config dictionary is nil (scene, view or model nil?)");
	
	NSDictionary* behaviorTemplates = [objectLayerNode.kkScene.kkView.model objectForKey:@"behaviorTemplates"];
	NSAssert(behaviorTemplates, @"view's behaviorTemplates config dictionary is nil (scene, view or model nil?)");
	
	// for each object on layer
	KKTilemapLayer* objectLayer = objectLayerNode.layer;
	for (KKTilemapObject* tilemapObject in objectLayer.objects)
	{
		NSString* objectType = tilemapObject.type;
		if (objectType)
		{
			// find the matching objectTemplates definition
			NSDictionary* objectDef = [objectTemplates objectForKey:objectType];
			
			NSString* objectClassName = [objectDef objectForKey:@"className"];
			NSAssert2(objectClassName, @"Can't create object named '%@' (object type: '%@') - 'nodeClass' entry missing for object & its parents. Check objectTemplates.lua", tilemapObject.name, objectType);
			
			Class objectNodeClass = NSClassFromString(objectClassName);
			NSAssert3(objectNodeClass, @"Can't create object named '%@' (object type: '%@') - no such class: %@", tilemapObject.name, objectType, objectClassName);
			NSAssert3([objectNodeClass isSubclassOfClass:[SKNode class]], @"Can't create object named '%@' (object type: '%@') - class '%@' does not inherit from SKNode", tilemapObject.name, objectType, objectClassName);
			
			// use a custom initializer where appropriate
			SKNode* objectNode;
			NSString* initMethodName = [objectDef objectForKey:@"initMethod"];
			if (initMethodName.length)
			{
				NSString* paramName = [objectDef objectForKey:@"initParam"];

				// get param from Tiled properties
				NSMutableDictionary* tilemapObjectProperties = tilemapObject.properties.properties;
				id param = [tilemapObjectProperties objectForKey:paramName];
				[tilemapObjectProperties removeObjectForKey:paramName];

				// get param from objectTemplates.lua instead
				if (param == nil)
				{
					param = [objectDef objectForKey:paramName];
				}
				
				SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING(objectNode = [objectNodeClass performSelector:NSSelectorFromString(initMethodName)
																						  withObject:param]);
				
				if ([objectNode isKindOfClass:[SKEmitterNode class]])
				{
					// prevents assertions in KKVarSetter
					objectClassName = @"SKEmitterNode";
				}
			}
			else
			{
				objectNode = [objectNodeClass node];
			}
			
			objectNode.position = CGPointMake(tilemapObject.position.x + tilemapObject.size.width / 2.0, tilemapObject.position.y + tilemapObject.size.height / 2.0);
			objectNode.hidden = tilemapObject.hidden;
			objectNode.zRotation = tilemapObject.rotation;
			objectNode.name = (tilemapObject.name.length ? tilemapObject.name : objectClassName);

			// apply node properties & ivars
			NSDictionary* nodeProperties = [objectDef objectForKey:@"properties"];
			if (nodeProperties.count)
			{
				KKClassVarSetter* varSetter = [varSetterCache objectForKey:objectClassName];
				if (varSetter == nil)
				{
					varSetter = [[KKClassVarSetter alloc] initWithClass:objectNodeClass];
					[varSetterCache setObject:varSetter forKey:objectClassName];
				}
				
				[varSetter setIvarsWithDictionary:nodeProperties target:objectNode];
				[varSetter setPropertiesWithDictionary:nodeProperties target:objectNode];
				
				//NSLog(@"\tproperties: %@", properties);
			}

			//NSLog(@"---> Spawned object: %@", objectClassName);
			
			// create physics body
			NSDictionary* physicsBodyDef = [objectDef objectForKey:@"physicsBody"];
			if (physicsBodyDef.count)
			{
				SKPhysicsBody* body = [objectNode physicsBodyWithTilemapObject:tilemapObject];
				if (body)
				{
					// apply physics body object properties & ivars
					NSDictionary* properties = [physicsBodyDef objectForKey:@"properties"];
					if (properties.count)
					{
						KKClassVarSetter* varSetter = [varSetterCache objectForKey:@"PKPhysicsBody"];
						[varSetter setPropertiesWithDictionary:properties target:body];
					}
				}
				
				//NSLog(@"\tphysicsBody: %@", properties);
			}
			
			// create and add behaviors
			NSDictionary* behaviors = [objectDef objectForKey:@"behaviors"];
			for (NSString* behaviorDefKey in behaviors)
			{
				NSDictionary* behaviorDef = [behaviors objectForKey:behaviorDefKey];
				KKBehavior* behavior = [self behaviorWithTemplate:behaviorDef objectNode:objectNode varSetterCache:varSetterCache];
				
				[objectNode addBehavior:behavior withKey:behaviorDefKey];
			}
			
			// override properties with properties from Tiled
			NSMutableDictionary* tiledProperties = tilemapObject.properties.properties;
			if (tiledProperties.count)
			{
				KKClassVarSetter* varSetter = [varSetterCache objectForKey:objectClassName];
				if (varSetter == nil)
				{
					varSetter = [[KKClassVarSetter alloc] initWithClass:objectNodeClass];
					[varSetterCache setObject:varSetter forKey:objectClassName];
				}
				
				// process behavior templates first
				for (NSString* propertyKey in tiledProperties.allKeys)
				{
					// test if a behavior template property exists
					NSDictionary* behaviorTemplate = [behaviorTemplates objectForKey:propertyKey];
					if (behaviorTemplate)
					{
						// test if the behavior is enabled, and remove the key to avoid varsetter from trying to "set" it
						KKMutableNumber* behaviorEnabled = [tiledProperties objectForKey:propertyKey];
						[tiledProperties removeObjectForKey:propertyKey];
						
						if (behaviorEnabled.boolValue)
						{
							KKBehavior* behavior = [self behaviorWithTemplate:behaviorTemplate objectNode:objectNode varSetterCache:varSetterCache];
							[objectNode addBehavior:behavior withKey:propertyKey];
						}
					}
				}

				[varSetter setIvarsWithDictionary:tiledProperties target:objectNode];
				[varSetter setPropertiesWithDictionary:tiledProperties target:objectNode];

				//NSLog(@"\tTiled properties: %@", properties);
			}

			[objectLayerNode addChild:objectNode];

			// call objectDidSpawn on newly spawned object (if available)
			if ([objectNode respondsToSelector:@selector(nodeDidSpawnWithTilemapObject:)])
			{
				[objectNode performSelector:@selector(nodeDidSpawnWithTilemapObject:) withObject:tilemapObject];
			}
		}
	}
}

-(KKBehavior*) behaviorWithTemplate:(NSDictionary*)behaviorDef objectNode:(SKNode*)objectNode varSetterCache:(NSMutableDictionary*)varSetterCache
{
	NSString* behaviorClassName = [behaviorDef objectForKey:@"className"];
	NSAssert1(behaviorClassName, @"Can't create behavior (%@) - 'behaviorClass' entry missing. Check objectTemplates.lua", behaviorDef);
	
	Class behaviorClass = NSClassFromString(behaviorClassName);
	NSAssert1(behaviorClass, @"Can't create behavior named '%@' - no such behavior class", behaviorClassName);
	NSAssert1([behaviorClass isSubclassOfClass:[KKBehavior class]], @"Can't create behavior named '%@' - class does not inherit from KKBehavior", behaviorClassName);
	
	KKBehavior* behavior = [behaviorClass behavior];
	
	// apply behavior properties & ivars
	NSDictionary* behaviorProperties = [behaviorDef objectForKey:@"properties"];
	if (behaviorProperties.count)
	{
		KKClassVarSetter* varSetter = [varSetterCache objectForKey:behaviorClassName];
		if (varSetter == nil)
		{
			varSetter = [[KKClassVarSetter alloc] initWithClass:behaviorClass];
			[varSetterCache setObject:varSetter forKey:behaviorClassName];
		}
		
		[varSetter setIvarsWithDictionary:behaviorProperties target:behavior];
		[varSetter setPropertiesWithDictionary:behaviorProperties target:behavior];
	}
	
	return behavior;
}

#pragma mark Objects

-(KKTilemapObject*) objectNamed:(NSString*)name
{
	for (KKTilemapObjectLayerNode* objectLayerNode in _objectLayerNodes)
	{
		for (KKTilemapObject* object in objectLayerNode.layer.objects)
		{
			if ([object.name isEqualToString:name])
			{
				return object;
			}
		}
	}
	return nil;
}

#pragma mark Bounds

@dynamic bounds;
-(CGRect) bounds
{
	CGRect bounds = CGRectMake(INFINITY, INFINITY, INFINITY, INFINITY);
	KKTilemapLayer* mainLayer = _mainTileLayerNode.layer;
	if (mainLayer.endlessScrollingHorizontal == NO)
	{
		bounds.origin.x = 0.0;
		bounds.size.width = _tilemap.size.width * _tilemap.gridSize.width;
	}
	if (mainLayer.endlessScrollingVertical == NO)
	{
		bounds.origin.y = 0.0;
		bounds.size.height = _tilemap.size.height * _tilemap.gridSize.height;
	}
	return bounds;
}

@end