/**
 * @author javdevgames http://coding.javdev.com
 *
 * DepthBufferTests
 * The MIT License (MIT)
 * Copyright (c) 2015 javdevgames
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 * 
 */

package  
{
	import com.GameScene;
	import flare.basic.Scene3D;
	import flare.basic.Viewer3D;
	import flare.core.Pivot3D;
	import flare.core.Texture3D;
	import flare.flsl.FLSL;
	import flare.flsl.FLSLMaterial;
	import flare.materials.filters.ColorFilter;
	import flare.materials.filters.TextureMapFilter;
	import flare.materials.Material3D;
	import flare.materials.Shader3D;
	import flare.primitives.Cube;
	import flare.primitives.Plane;
	import flare.primitives.Sphere;
	import flare.system.Device3D;
	import flare.system.Input3D;
	import flash.display.BitmapData;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.geom.Vector3D;
	import flash.utils.getTimer;
	
	public class DepthBufferTests extends Sprite 
	{
		
		[Embed(source = "../bin/mrt.flsl.compiled", mimeType = "application/octet-stream")]
		private var flsl:Class;
		
		[Embed(source="../bin/depth_glow_test.flsl.compiled", mimeType="application/octet-stream")]
		private var depthGlowFLSL:Class;
		
		[Embed(source="../bin/floorTexture.png")]
		private var floorAsset:Class;
		
		private static var POSITION_HELPER:Vector3D = new Vector3D();
		
		private var mScene:Scene3D;
		private var mColorBuffer:Texture3D;
		private var mDepthTexture:Texture3D;
		private var mEffectBuffer:Texture3D;
		private var mTargetBuffer:Texture3D;
		private var mMRT:FLSLMaterial;
		
		private var mDepthMaterial:FLSLMaterial;
		
		private var mSphere:Pivot3D;
		private var startModel:Pivot3D;
		private var mRenderMaterial:Shader3D;
		private var mFloorMaterial:Shader3D;
		private var mGameScene:GameScene;
		
		private var mLastTime:Number;
		private var mFloorTexture:Texture3D;
		private var mRedTexture:Texture3D;
		
		public function DepthBufferTests() 
		{
			FLSL.agalVersion = 2;
			Device3D.profile = "standard";
			
			//setup the scene
			mScene = new Viewer3D(stage, null, 0.4);
			mScene.skipFrames = false;
			mScene.autoResize = true;
			mScene.antialias = 2;
			mScene.showLogo = false;
			
			SetupTextures();
			SetupMaterials();
			
			mScene.addEventListener(Scene3D.RENDER_EVENT, SetupEvent);
			mScene.clearColor.setTo(0, 0, 0);
			
			mLastTime = getTimer();
		}
		
		private function SetupEvent(e:Event):void 
		{
			mScene.removeEventListener(Scene3D.RENDER_EVENT, SetupEvent);
			
			//set everythng else up
			mScene.context.enableErrorChecking = true;
			mScene.addEventListener(Scene3D.RENDER_EVENT, RenderEvent);
			mScene.addEventListener(Scene3D.UPDATE_EVENT, OnUpdate);
			
			mScene.camera.setPosition( -170, 198, -268);
			mScene.camera.lookAt(0, 0, 0);
			
			mMRT = new FLSLMaterial( "", new flsl, null, true ); 
			
			//setup the depth material
			AddEffectsMesh();
			
			mGameScene = new GameScene(mScene, mFloorMaterial, mRenderMaterial);		
		}
		
		private function SetupTextures():void
		{
			var size:int = 1024;
			var bmp:BitmapData = new BitmapData(size, size);
			
			var format:int = Texture3D.FORMAT_RGBA_HALF_FLOAT;
			
			mColorBuffer = new Texture3D( bmp, true, format );
			SetupTexture(mColorBuffer);			
			mColorBuffer.upload( mScene );
			
			mDepthTexture = new Texture3D( bmp, true, format );
			SetupTexture(mDepthTexture);
			mDepthTexture.upload( mScene );
			
			mEffectBuffer = new Texture3D(bmp, true, format);
			SetupTexture(mEffectBuffer);
			mEffectBuffer.upload(mScene);
			
			mTargetBuffer = new Texture3D(bmp, true, format);
			SetupTexture(mTargetBuffer);
			mTargetBuffer.upload(mScene);
		}
		
		private function SetupMaterials():void
		{
			mRenderMaterial = new Shader3D("", [new ColorFilter(0x990000)]);
			
			mFloorTexture = new Texture3D(new floorAsset);
			mFloorMaterial = new Shader3D("", [new TextureMapFilter(mFloorTexture)]);
			
			mRedTexture = new Texture3D(new BitmapData(256, 256, false, 0xffAA0000));
			
			mDepthMaterial = new FLSLMaterial("", new depthGlowFLSL, "main", true);			
			mDepthMaterial.params.depthTexture.value = mDepthTexture;			
			mDepthMaterial.blendMode = Material3D.BLEND_ADDITIVE;
		}
		
		private function SetupTexture(tex:Texture3D):void 
		{
			tex.typeMode = Texture3D.TYPE_2D;
		}
		
		private function RenderEvent(e:Event):void 
		{
			e.preventDefault();
			
			if ( !mScene.context )
			{
				return;
			}
			
			//Update the input, etc.
			mScene.update();
			
			mScene.setMaterial( mMRT );
			
			//And begin the rendering process
			RenderSceneToRenderTargets();
			RenderEffectsToRenderTargets();
			ComposeImageFromRenderTargets();
		}
		
		private function RenderSceneToRenderTargets():void 
		{
			mScene.context.setRenderToTexture( mColorBuffer.texture, true, 0, 0, 0 );
			mScene.context.setRenderToTexture( mDepthTexture.texture, true, 0, 0, 1 );
			mScene.context.clear(0,0,0,1);
			
			mMRT.setTechnique("main");
			
			// setup some global matrices and constant configurations.
			mScene.setupFrame( mScene.camera );
			
			// go trough each object to draw one by one.
			for each ( var p:Pivot3D in mScene.renderList )
			{
				if (p is Cube)
				{
					mMRT.params.materialTexture.value = mRedTexture;
					p.draw(false, mMRT);
				}
				else if (p is Plane)
				{
					mMRT.params.materialTexture.value = mFloorTexture;
					p.draw(false, mMRT);
				}
			}
			
			// release GPU states.
			mScene.endFrame();
			
			mScene.context.setRenderToTexture( null, false, 0, 0, 0 );
			mScene.context.setRenderToTexture( null, false, 0, 0, 1 );
		}
		
		private function RenderEffectsToRenderTargets():void 
		{
			mScene.context.setRenderToTexture(mEffectBuffer.texture, true, 0, 0, 0 );
			mScene.context.clear(0, 0, 0, 1);
			
			mSphere.draw(false, mDepthMaterial);
			
			mScene.context.setRenderToTexture(null, false, 0, 0, 0 );
		}
		
		private function ComposeImageFromRenderTargets():void 
		{
			//finally, compose the everything
			mScene.context.setRenderToTexture(mTargetBuffer.texture, true, 0, 0, 0 );
			mScene.context.clear(0, 0, 0, 1);
			
			mMRT.setTechnique("compose");
			
			mMRT.params.colorBuffer.value = mColorBuffer;
			mMRT.params.effectBuffer.value = mEffectBuffer;
			mMRT.drawQuad();
			
			mScene.context.setRenderToTexture(null, false, 0, 0, 0 );
			mScene.context.clear(0, 0, 0, 1);
			
			mScene.context.setRenderToBackBuffer();
			
			mScene.drawQuadTexture(mTargetBuffer, 0, 0, stage.stageWidth, stage.stageHeight);
		}
		
		private function AddEffectsMesh():void
		{
			mSphere = new Sphere("", 40, 24, mDepthMaterial);			
			mScene.addChild(mSphere);
		}		
		
		private function OnUpdate(e:Event):void 
		{
			var curTime:Number = getTimer();
			var diff:Number = curTime - mLastTime;
			
			//for moving the sphere around, based on the camera's direction
			const speed:Number = 0.8 * (diff / 16);
			
			
			if (Input3D.keyDown(Input3D.W))
			{
				POSITION_HELPER.x += mScene.camera.getDir().x;
				POSITION_HELPER.z += mScene.camera.getDir().z;
			}
			else if (Input3D.keyDown(Input3D.S))
			{
				POSITION_HELPER.x -= mScene.camera.getDir().x;
				POSITION_HELPER.z -= mScene.camera.getDir().z;
			}
			
			if (Input3D.keyDown(Input3D.A))
			{
				POSITION_HELPER.x += mScene.camera.getLeft().x;
				POSITION_HELPER.z += mScene.camera.getLeft().z;
			}
			else if (Input3D.keyDown(Input3D.D))
			{
				POSITION_HELPER.x -= mScene.camera.getLeft().x;
				POSITION_HELPER.z -= mScene.camera.getLeft().z;
			}
			
			if (Input3D.keyDown(Input3D.DOWN))
			{
				POSITION_HELPER.y -= speed;
			}
			else if (Input3D.keyDown(Input3D.UP))
			{
				POSITION_HELPER.y += speed;
			}
			
			//update the final position
			mSphere.setPosition(POSITION_HELPER.x, POSITION_HELPER.y, POSITION_HELPER.z);
			
			mLastTime = curTime;
		}
	}
}