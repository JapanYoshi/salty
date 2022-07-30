shader_type canvas_item;

uniform vec2 canvas_size = vec2(1280., 720.);
uniform float scale:hint_range(0.5, 5.0);
uniform float p_time:hint_range(0.0, 1.0);
uniform vec4 add_color:hint_color = vec4(1, 1, 1, 1);

// uniform noise, pre-generated.
// GLES2 supports neither arrays nor switch-case statements,
// so I'm forced to do THIS bullshit
float rfloat(int i) {
	if ((i % 32) < 16) {
	  if ((i % 16) < 8) {
	    if ((i % 8) < 4) {
	      if ((i % 4) < 2) {
	        if ((i % 2) < 1) {
	          return 0.870967;
	        } else {
	          return 0.580645;
	        }
	      } else {
	        if ((i % 2) < 1) {
	          return 0.193548;
	        } else {
	          return 0.774193;
	        }
	      }
	    } else {
	      if ((i % 4) < 2) {
	        if ((i % 2) < 1) {
	          return 0.838709;
	        } else {
	          return 0.225806;
	        }
	      } else {
	        if ((i % 2) < 1) {
	          return 0.806451;
	        } else {
	          return 0.161290;
	        }
	      }
	    }
	  } else {
	    if ((i % 8) < 4) {
	      if ((i % 4) < 2) {
	        if ((i % 2) < 1) {
	          return 0.967741;
	        } else {
	          return 0.741935;
	        }
	      } else {
	        if ((i % 2) < 1) {
	          return 0.096774;
	        } else {
	          return 0.645161;
	        }
	      }
	    } else {
	      if ((i % 4) < 2) {
	        if ((i % 2) < 1) {
	          return 0.032258;
	        } else {
	          return 0.000000;
	        }
	      } else {
	        if ((i % 2) < 1) {
	          return 0.935483;
	        } else {
	          return 0.677419;
	        }
	      }
	    }
	  }
	} else {
	  if ((i % 16) < 8) {
	    if ((i % 8) < 4) {
	      if ((i % 4) < 2) {
	        if ((i % 2) < 1) {
	          return 0.290322;
	        } else {
	          return 0.354838;
	        }
	      } else {
	        if ((i % 2) < 1) {
	          return 0.064516;
	        } else {
	          return 0.387096;
	        }
	      }
	    } else {
	      if ((i % 4) < 2) {
	        if ((i % 2) < 1) {
	          return 0.451612;
	        } else {
	          return 0.258064;
	        }
	      } else {
	        if ((i % 2) < 1) {
	          return 1.000000;
	        } else {
	          return 0.129032;
	        }
	      }
	    }
	  } else {
	    if ((i % 8) < 4) {
	      if ((i % 4) < 2) {
	        if ((i % 2) < 1) {
	          return 0.709677;
	        } else {
	          return 0.322580;
	        }
	      } else {
	        if ((i % 2) < 1) {
	          return 0.548387;
	        } else {
	          return 0.516129;
	        }
	      }
	    } else {
	      if ((i % 4) < 2) {
	        if ((i % 2) < 1) {
	          return 0.612903;
	        } else {
	          return 0.903225;
	        }
	      } else {
	        if ((i % 2) < 1) {
	          return 0.483870;
	        } else {
	          return 0.419354;
	        }
	      }
	    }
	  }
	}
}

const int COUNT = 16;

void fragment() {
	// the vec2(0.5, 0.5) business it to center the coordinate system
	vec2 uv = (
		UV - vec2(0.5, 0.5)
	) * scale * canvas_size / 1024.;
	float v = 0.; // total brightness, how much of the overlay color to blend

	for (int i = 0; i < COUNT; i++) {
		float rOffset = rfloat(i);
		float rSize = rfloat(1 + i * 3);
		float rXPosition = rfloat(2 + i * 7);
		float rYPosition = rfloat(3 + i * 13);
		// generate the properties
		// offset time
        float time = fract(p_time + rOffset);
		float size = 0.05 + 0.25 * rSize;
		// x offset from -1 to 1
		float pos = 2. * (rXPosition - 0.5);
		// y offset from -0.6 to 0.6
		float ypos = 1.2 * (rYPosition - 0.5);
		// antialias width (used for y only)
		// float aa = fwidth(uv.y) * 1.;
		// fwidth(float) is unsupported on GLES2, give up

		// generate square bounds
		float alphaX = step(abs(uv.x - pos), size);
		// y bounds move with time
		/*
		float alphaY = smoothstep(
				-aa, aa,
				size - abs(uv.y - (p_time - 0.5) * 3. * size + ypos)
		);
		*/
		float alphaY = step(0, size - abs(uv.y + (time - 0.5) * 2. * size + ypos));
		// squares fade in/out
		float alphaTime = 0.5 - abs(0.5 - time);

		float alpha = alphaX * alphaY * alphaTime;

		v = mix(v, 1., alpha);
	}
	
	COLOR.rgb = mix(COLOR.rgb, add_color.rgb, v);
	COLOR.a = 1.0;
}