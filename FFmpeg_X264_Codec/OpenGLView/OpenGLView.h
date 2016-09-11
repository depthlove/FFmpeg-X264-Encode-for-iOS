//
//  OpenGLView.h
//  FFmpeg_X264_Codec
//
//  Created by suntongmian on 16/9/11.
//  Copyright © 2016年 suntongmian@163.com. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreVideo/CoreVideo.h>
#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/gltypes.h>
#import <OpenGLES/EAGLDrawable.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>

#ifdef DEBUG
#define DLog(...) printf(__VA_ARGS__);
#else
#define DLog(...) {}
#endif

enum {
    ATTRIBUTE_VERTEX,
   	ATTRIBUTE_TEXCOORD,
};


static void mat4f_LoadOrtho(float left, float right, float bottom, float top, float near, float far, float* mout)
{
    float r_l = right - left;
    float t_b = top - bottom;
    float f_n = far - near;
    float tx = - (right + left) / (right - left);
    float ty = - (top + bottom) / (top - bottom);
    float tz = - (far + near) / (far - near);
    
    mout[0] = 2.0f / r_l;
    mout[1] = 0.0f;
    mout[2] = 0.0f;
    mout[3] = 0.0f;
    
    mout[4] = 0.0f;
    mout[5] = 2.0f / t_b;
    mout[6] = 0.0f;
    mout[7] = 0.0f;
    
    mout[8] = 0.0f;
    mout[9] = 0.0f;
    mout[10] = -2.0f / f_n;
    mout[11] = 0.0f;
    
    mout[12] = tx;
    mout[13] = ty;
    mout[14] = tz;
    mout[15] = 1.0f;
}



static const GLfloat texCoords[] = {
    0.0f, 1.0f,
    1.0f, 1.0f,
    0.0f, 0.0f,
    1.0f, 0.0f,
};

static const char* shader_vsh =
"attribute vec4 position;"
"attribute vec2 texcoord;"
"uniform mat4 modelViewProjectionMatrix;"
"varying vec2 v_texcoord;"

"void main() {"
"    gl_Position = modelViewProjectionMatrix * position;"
"    v_texcoord = texcoord.xy;"
"}";

static const char* shader_fsh =
"precision mediump float;"
"varying vec2 v_texcoord;"
"uniform sampler2D s_texture;"

"void main() {"
"    gl_FragColor = texture2D(s_texture, v_texcoord);"
"}";

static inline GLuint compileShader(GLuint type, const char * source)
{
    GLint status;

    GLuint shader = glCreateShader(type);
    if (shader == 0 || shader == GL_INVALID_ENUM) {
        DLog("Failed to create shader %d\n", type);
        return 0;
    }

    glShaderSource(shader, 1, &source, NULL);
    glCompileShader(shader);
    
#ifdef DEBUG
    GLint logLength;
    glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0)
    {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(shader, logLength, &logLength, log);
        DLog("Shader compile log:\n%s\n", log);
        free(log);
    }
#endif
    
    glGetShaderiv(shader, GL_COMPILE_STATUS, &status);
    if (status == GL_FALSE) {
        glDeleteShader(shader);
        DLog("Failed to compile shader:\n");
        return 0;
    }
    
    return shader;
}

static BOOL validateProgram(GLuint prog)
{
    GLint status;
    
    glValidateProgram(prog);
    
#ifdef DEBUG
    GLint logLength;
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0)
    {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        DLog("Program validate log:\n%s\n", log);
        free(log);
    }
#endif
    
    glGetProgramiv(prog, GL_VALIDATE_STATUS, &status);
    if (status == GL_FALSE) {
        DLog("Failed to validate program %d\n", prog);
        return NO;
    }
    
    return YES;
}


@interface OpenGLView : UIView

- (void)render:(CVPixelBufferRef)pixelBuffer;

@end
