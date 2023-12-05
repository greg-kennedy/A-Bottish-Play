/**
 * Letters. 
 * 
 * Draws letters to the screen. This requires loading a font, 
 * setting the font, and then drawing the letters.
 */

int catEmoji[] = {
  0x0001f431,
  0x0001f638,
  0x0001f639,
  0x0001f63a,
  0x0001f63b,
  0x0001f63c,
  0x0001f63d,
  0x0001f63e,
  0x0001f63f,
  0x0001f640,
  0x0001f408
};
PFont f;

void setup() {

  size(960, 720);
background(0);
  // Create the font
//  printArray(PFont.list());
  f = createFont("Segoe UI Emoji", 24);
  textFont(f);
  textAlign(CENTER, CENTER);


  // draw 32129 cat faces in there
  float frame_count = ((7 * 60) + 56.5) * 24;
  int cat_count = 0;

  for (int frame = 0; frame < frame_count; frame ++) {
    while (cat_count < frame / frame_count * 32129) {
      // Draw the letter to the screen
      fill(random(255), random(255), random(255));
      text(new String(Character.toChars(catEmoji[int(random(11))])), random(width), random(height));
  //      text("cat", random(width), random(height));
      cat_count ++;
    }
    save("output/i-" + nf(frame,5) + ".png");
    if (frame % 1000 == 0) {
      println("Drawn " + cat_count + " cats by frame " + frame);
    }
  }

  println("Drawn " + cat_count + " cats.");
}
