package graphics;

import lime._internal.graphics.ImageDataUtil;
import lime.graphics.Image;
import lime.math.Vector2;
import utest.Assert;
import utest.Test;

class ImageDataUtilTest extends Test
{
	public function new()
	{
		super();
	}

	// on Flash, an Image is not of the DATA type and keeps the scan through getPixel32
	public function testGetColorBoundsRectFindsWhatAScanOfEveryPixelFinds()
	{
		// with masks of the alpha alone, of one channel and of all four, on images that hold nothing, a few
		// pixels or many, alone in their buffer or a part of it
		var masks = [0xFF000000, 0xFFFFFFFF, 0x00FFFFFF, 0x0000FF00, 0x000000FF, 0];
		var seed = 7;

		function next(n:Int):Int
		{
			seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
			return (seed >> 8) % n;
		}

		var differences = 0;

		for (round in 0...240)
		{
			var buffer = new Image(null, 0, 0, 1 + next(12), 1 + next(12), 0x00000000);
			var filled = next(4);

			for (y in 0...buffer.height)
			{
				for (x in 0...buffer.width)
				{
					if (filled > 0 && next(filled == 1 ? 9 : 2) == 0)
					{
						buffer.setPixel32(x, y, (next(256) << 24) | (next(256) << 16) | (next(256) << 8) | next(256), ARGB32);
					}
				}
			}

			if (next(2) == 0) buffer.premultiplied = true;

			var image = buffer;

			if (next(3) == 0)
			{
				var x = next(buffer.width), y = next(buffer.height);
				image = new Image(buffer.buffer, x, y, 1 + next(buffer.width - x), 1 + next(buffer.height - y));
			}

			var mask = masks[next(masks.length)];
			var color = switch (next(3))
			{
				case 0: 0;
				case 1: mask & (next(256) * 0x01010101);
				default: image.getPixel32(next(image.width), next(image.height), ARGB32);
			}
			var findColor = next(2) == 0;

			var left = image.width, top = image.height, right = -1, bottom = -1;

			for (y in 0...image.height)
			{
				for (x in 0...image.width)
				{
					var hit = (image.getPixel32(x, y, ARGB32) & mask) == color;

					if (hit == findColor)
					{
						if (x < left) left = x;
						if (x > right) right = x;
						if (y < top) top = y;
						if (y > bottom) bottom = y;
					}
				}
			}

			var rect = image.getColorBoundsRect(mask, color, findColor, ARGB32);
			var same = right < 0 ? (rect.width == 0 && rect.height == 0) : (rect.x == left && rect.y == top && rect.width == right - left + 1
				&& rect.height == bottom - top + 1);

			if (!same) differences++;
		}

		Assert.equals(0, differences);
	}

	// on Flash, the pixels of an Image are in a flash.display.BitmapData, not in the data this blur reads
	#if !flash
	public function testGaussianBlurMultipliesTheBlurredAlphaByTheStrength()
	{
		var plain = blurredDot(1);
		var strong = blurredDot(4);

		var edge = plain.getPixel32(5, 4) & 0xFF;
		Assert.isTrue(edge > 0 && edge < 0x40, "the blur did not spread the dot: " + edge);
		Assert.equals(edge * 4, strong.getPixel32(5, 4) & 0xFF);

		var far = plain.getPixel32(6, 4) & 0xFF;
		Assert.equals(Std.int(Math.min(0xFF, far * 4)), strong.getPixel32(6, 4) & 0xFF);

		// the alpha stays within a byte
		Assert.equals(0xFF, blurredDot(255).getPixel32(4, 4) & 0xFF);
	}

	public function testGaussianBlurOfTheAlphaAloneWritesTheSameAlpha()
	{
		var seed = 11;

		function next(n:Int):Int
		{
			seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
			return (seed >> 8) % n;
		}

		for (round in 0...60)
		{
			// two rows at least: the blur reads the row under the first one
			var width = 1 + next(24), height = 2 + next(24);
			var premultiplied = next(2) == 0;
			var colors = [for (i in 0...width * height) next(3) == 0 ? (next(256) << 24) | (next(256) << 16) | (next(256) << 8) | next(256) : 0];
			var blurX = next(4) == 0 ? 0 : next(33), blurY = next(4) == 0 ? 0 : next(33), quality = next(5);
			var strength = [1.0, 2.0, 0.5][next(3)];
			var message = "round " + round + ", " + width + "x" + height + ", blur " + blurX + "x" + blurY + ", quality " + quality;

			var images = [];

			for (alphaOnly in [false, true])
			{
				var pair = [];

				for (i in 0...2)
				{
					var image = new Image(null, 0, 0, width, height, 0x00000000);

					for (y in 0...height)
					{
						for (x in 0...width)
						{
							image.setPixel32(x, y, colors[y * width + x], ARGB32);
						}
					}

					image.premultiplied = premultiplied;
					pair.push(image);
				}

				ImageDataUtil.gaussianBlur(pair[0], pair[1], pair[1].rect, new Vector2(), blurX, blurY, quality, strength, null, alphaOnly);
				images.push(pair[0]);
			}

			var same = true, clear = true;

			for (i in 0...width * height)
			{
				if (images[1].data[i * 4 + 3] != images[0].data[i * 4 + 3]) same = false;
				if (images[1].data[i * 4] != 0 || images[1].data[i * 4 + 1] != 0 || images[1].data[i * 4 + 2] != 0) clear = false;
			}

			Assert.isTrue(same, "another alpha, " + message);
			Assert.isTrue(clear, "a color left, " + message);
			Assert.equals(premultiplied, images[1].premultiplied);
		}
	}

	private static function blurredDot(strength:Float):Image
	{
		var source = new Image(null, 0, 0, 9, 9, 0x00000000);
		source.setPixel32(4, 4, 0xFFFFFFFF);
		var image = new Image(null, 0, 0, 9, 9, 0x00000000);
		ImageDataUtil.gaussianBlur(image, source, source.rect, new Vector2(), 4, 4, 1, strength);
		return image;
	}
	#end
}
