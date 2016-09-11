//
//  OpenGLView.m
//  FFmpeg_X264_Codec
//
//  Created by suntongmian on 16/9/11.
//  Copyright © 2016年 suntongmian@163.com. All rights reserved.
//

#import "OpenGLView.h"

@interface OpenGLView ()
{
    EAGLContext                 *_context;
    
    GLuint                      _framebuffer;
    GLuint                      _renderbuffer;
    
    GLint                       _backingWidth; // UIView width
    GLint                       _backingHeight; // UIView height
    
    GLuint                      _program;
    GLint                       _uniformMatrix;
    GLfloat                     _vertices[8];
    GLint                       _uniformSampler;
    
    int                         _frameWidth;
    int                         _frameHeight;
    
    CVOpenGLESTextureCacheRef   _textureCache;
    CVOpenGLESTextureRef        _glTexture;
}
@end

@implementation OpenGLView
{
    
}

+ (Class)layerClass {
    return [CAEAGLLayer class];
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        
        _frameWidth = 1920;
        _frameHeight = 1080;
        
        
        CAEAGLLayer *glLayer = (CAEAGLLayer *)self.layer;
        glLayer.opaque = YES;
        glLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithBool:FALSE], kEAGLDrawablePropertyRetainedBacking,
                                        kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat,
                                        nil];

        
        EAGLRenderingAPI rendingAPI = kEAGLRenderingAPIOpenGLES2;
        _context = [[EAGLContext alloc] initWithAPI:rendingAPI];
        if (!_context ||
            ![EAGLContext setCurrentContext:_context]) {
            
            DLog("failed to setup EAGLContext\n");
            self = nil;
            return nil;
        }
        
        glGenRenderbuffers(1, &_renderbuffer);
        glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
        [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer*)self.layer];
        glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_backingWidth);
        glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_backingHeight);
        
        glGenFramebuffers(1, &_framebuffer);
        glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _renderbuffer);
        
        GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
        if (status != GL_FRAMEBUFFER_COMPLETE) {
            
            DLog("failed to make complete framebuffer object %x\n", status);
            self = nil;
            return nil;
        }
        
        GLenum glError = glGetError();
        if (GL_NO_ERROR != glError) {
            
            DLog("failed to setup GL %x\n", glError);
            self = nil;
            return nil;
        }
        
        if (![self loadShaders]) {
            
            self = nil;
            return nil;
        }
        
        _vertices[0] = -1.0f;  // x0
        _vertices[1] = -1.0f;  // y0
        _vertices[2] =  1.0f;  // ..
        _vertices[3] = -1.0f;
        _vertices[4] = -1.0f;
        _vertices[5] =  1.0f;
        _vertices[6] =  1.0f;  // x3
        _vertices[7] =  1.0f;  // y3
        
        CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, _context, NULL, &(_textureCache));
        if (err != noErr) {
            DLog("Error at CVOpenGLESTextureCacheCreate %d\n", err);
            return nil;
        }
        
        DLog("OK setup GL");
    }
    return self;
}

- (void)dealloc
{
    if (_framebuffer) {
        glDeleteFramebuffers(1, &_framebuffer);
        _framebuffer = 0;
    }
    
    if (_renderbuffer) {
        glDeleteRenderbuffers(1, &_renderbuffer);
        _renderbuffer = 0;
    }
    
    if (_program) {
        glDeleteProgram(_program);
        _program = 0;
    }
    
    [self cleanUpTexture];
    
    if(_textureCache) {
        CFRelease(_textureCache);
        _textureCache = NULL;
    }
    
    if ([EAGLContext currentContext] == _context) {
        [EAGLContext setCurrentContext:nil];
    }
    
    _context = nil;
}

- (void)layoutSubviews {
    glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
    [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer*)self.layer];
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_backingHeight);
    
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (status != GL_FRAMEBUFFER_COMPLETE) {
        
        DLog("failed to make complete framebuffer object %x\n", status);
        
    } else {
        
        DLog("OK setup GL framebuffer %d:%d\n", _backingWidth, _backingHeight);
    }
    
    [self updateVertices];
    [self render: nil];
}

- (void)setContentMode:(UIViewContentMode)contentMode {
    [super setContentMode:contentMode];
    [self updateVertices];
    
    // GLuint _texture <=> CVOpenGLESTextureGetName(_glTexture)
    if (CVOpenGLESTextureGetName(_glTexture) != 0)
        [self render:nil];
}

- (BOOL)loadShaders {
    BOOL result = NO;
    GLuint vertShader = 0, fragShader = 0;
    
    _program = glCreateProgram();
    
    vertShader = compileShader(GL_VERTEX_SHADER, shader_vsh);
    if (!vertShader)
        goto exit;
    
    fragShader = compileShader(GL_FRAGMENT_SHADER, shader_fsh);
    if (!fragShader)
        goto exit;
    
    glAttachShader(_program, vertShader);
    glAttachShader(_program, fragShader);
    glBindAttribLocation(_program, ATTRIBUTE_VERTEX, "position");
    glBindAttribLocation(_program, ATTRIBUTE_TEXCOORD, "texcoord");
    
    glLinkProgram(_program);
    
    GLint status;
    glGetProgramiv(_program, GL_LINK_STATUS, &status);
    if (status == GL_FALSE) {
        DLog("Failed to link program %d\n", _program);
        goto exit;
    }
    
    result = validateProgram(_program);
    
    _uniformMatrix = glGetUniformLocation(_program, "modelViewProjectionMatrix");
    _uniformSampler = glGetUniformLocation(_program, "s_texture");
    
exit:
    
    if (vertShader)
        glDeleteShader(vertShader);
    if (fragShader)
        glDeleteShader(fragShader);
    
    if (result) {
        
        DLog("OK setup GL program\n");
        
    } else {
        
        glDeleteProgram(_program);
        _program = 0;
    }
    
    return result;
}

- (void)updateVertices {
    const BOOL fit      = (self.contentMode == UIViewContentModeScaleAspectFit);
    const float width   = _frameWidth;
    const float height  = _frameHeight;
    const float dH      = (float)_backingHeight / height;
    const float dW      = (float)_backingWidth	  / width;
    const float dd      = fit ? MIN(dH, dW) : MAX(dH, dW);
    const float h       = (height * dd / (float)_backingHeight);
    const float w       = (width  * dd / (float)_backingWidth);
    
    _vertices[0] = - w;
    _vertices[1] = - h;
    _vertices[2] =   w;
    _vertices[3] = - h;
    _vertices[4] = - w;
    _vertices[5] =   h;
    _vertices[6] =   w;
    _vertices[7] =   h;
}

- (void)render:(CVPixelBufferRef)pixelBuffer {
    
    [EAGLContext setCurrentContext:_context];
    
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    glViewport(0, 0, _backingWidth, _backingHeight);
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    glUseProgram(_program);
    
    if (pixelBuffer) {
        
        int pixelBufferWidth = (int)CVPixelBufferGetWidth(pixelBuffer);
        int pixelBufferHeight = (int)CVPixelBufferGetHeight(pixelBuffer);
        
        [self cleanUpTexture];
        
        if( ! CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                           _textureCache,
                                                           pixelBuffer,
                                                           NULL,
                                                           GL_TEXTURE_2D,
                                                           GL_RGBA,
                                                           pixelBufferWidth,
                                                           pixelBufferHeight,
                                                           GL_BGRA,
                                                           GL_UNSIGNED_BYTE,
                                                           0,
                                                           &_glTexture) )
        {
            // GLuint _texture <=> CVOpenGLESTextureGetName(_glTexture)
            glBindTexture(CVOpenGLESTextureGetTarget(_glTexture), CVOpenGLESTextureGetName(_glTexture));
            glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_NEAREST);
            glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_NEAREST);
            glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_S,GL_CLAMP_TO_EDGE);
            glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_T,GL_CLAMP_TO_EDGE);
        }


        glActiveTexture(GL_TEXTURE0);

        glUniform1i(_uniformSampler, 0);
        
        GLfloat modelviewProj[16];
        mat4f_LoadOrtho(-1.0f, 1.0f, -1.0f, 1.0f, -1.0f, 1.0f, modelviewProj);
        glUniformMatrix4fv(_uniformMatrix, 1, GL_FALSE, modelviewProj);
        
        glVertexAttribPointer(ATTRIBUTE_VERTEX, 2, GL_FLOAT, 0, 0, _vertices);
        glEnableVertexAttribArray(ATTRIBUTE_VERTEX);
        glVertexAttribPointer(ATTRIBUTE_TEXCOORD, 2, GL_FLOAT, 0, 0, texCoords);
        glEnableVertexAttribArray(ATTRIBUTE_TEXCOORD);
        
    #if 0
        if (!validateProgram(_program))
        {
            DLog("Failed to validate program\n");
            return;
        }
    #endif
            
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    }
    
    glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
    [_context presentRenderbuffer:GL_RENDERBUFFER];
}

- (void)cleanUpTexture {
    if(_glTexture) {
        CFRelease(_glTexture);
        _glTexture=NULL;
    }
    CVOpenGLESTextureCacheFlush(_textureCache, 0);
}

@end
