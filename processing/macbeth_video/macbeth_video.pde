/**
 * Load and Display 
 * 
 * Images can be loaded and displayed to the screen at their actual size
 * or any other size. 
 */

PImage[] img = new PImage[28]; 

float lengths[] = {
35.832494,
224.804762,
448.161429,
192.578186,
219.744444,
113.820363,
241.666553,
210.669410,
241.774467,
501.219070,
129.589002,
406.758707,
165.499433,
82.743356,
479.358503,
117.173401,
162.268299,
505.643696,
242.388776,
740.420952,
210.172200,
111.525669,
195.794694,
81.669819,
164.106689,
54.400249,
111.673787,
268.432880
};

int iNum = 18;
int frame = 0;

void setup() {
  size(960, 720);
  // The image file must be in the data folder of the current sketch 
  // to load successfully
  for (int i = 0; i < 28; i ++) {
    img[i] = loadImage(i + ".png");  // Load the image into the program  
  }
//}

//void draw() {
  // Displays the image at its actual size at point (0,0)
  int allfra = 0;
  while (true) {
    float duration = (float)frame/24.0;
    if (duration > lengths[iNum]) {
      frame = 0;
      duration = 0;
      iNum ++;
      if (iNum > 27) {
        exit();
      }
    }
  
    float y = (img[iNum].height - 720) * (duration / lengths[iNum]);
    image(img[iNum], 0, -y);
    save("output/" + nf(allfra, 6) + ".png");
    frame ++;
    allfra ++;
  }
}
