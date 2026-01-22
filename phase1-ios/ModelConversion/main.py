import torch
from torchvision import transforms
from transformers import AutoModelForImageSegmentation
from PIL import Image
import coremltools as ct
from coremltools.converters.mil.input_types import ColorLayout

input_image_path = "img16.jpg"
device = 'cuda' if torch.cuda.is_available() else 'cpu'
net = AutoModelForImageSegmentation.from_pretrained('briaai/RMBG-1.4', trust_remote_code=True).eval().to(device)

image_size = (1024, 1024)
transform_image = transforms.Compose([
    transforms.Resize(image_size),
    transforms.ToTensor(),
    transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])
])

image = Image.open(input_image_path)
input_images = transform_image(image).unsqueeze(0).to(device)


class WrappedRMBG(torch.nn.Module):
    def __init__(self, net):
        super(WrappedRMBG, self).__init__()
        self.net = net
    
    def forward(self, image):
        result = self.net(image)[0][0]
        ma = torch.max(result)
        mi = torch.min(result)
        result = (result-mi)/(ma-mi)
        im_array = (result*255)
        return im_array

model = WrappedRMBG(net)


try:
    traced_model = torch.jit.trace(model, input_images)
except RuntimeError as e:
    print(f"Tracing failed: {e}")




mlmodel = ct.convert(
    traced_model,
    convert_to="mlprogram",
    inputs=[ct.ImageType(name="input", shape=input_images.shape, scale=1/255.0, bias=[-0.5,-0.5,-0.5])],
    outputs=[ct.ImageType(name="output",color_layout=ColorLayout.GRAYSCALE)]
)

mlmodel.author = "BRIA AI"
mlmodel.license = "CC BY-NC 4.0"
mlmodel.short_description = "BRIA-AI RMBG-1.4"
mlmodel.version = "1.0"

# Save the model
mlmodel.save("bria_rmbg1_4.mlpackage")
