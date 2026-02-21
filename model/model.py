import torch
from torch import nn
import torch.nn.functional as F
from torchstat import stat
from thop import profile
class CIFAR10Model(nn.Module):
    def __init__(self):
        super(CIFAR10Model, self).__init__()
        #32，32，3  32*32*(9+8+1)*3
        self.conv1_depth = nn.Conv2d(in_channels = 3,out_channels=3,kernel_size= 3, padding=1,groups=3)
        self.conv1_point = nn.Conv2d(in_channels=3,out_channels=32,kernel_size=1)
        self.maxpool1 = nn.MaxPool2d(2, 2)
        #16，16，32
        self.conv2_depth = nn.Conv2d(in_channels=32,out_channels=32, kernel_size=3, padding=1,groups=32)
        self.conv2_point = nn.Conv2d(in_channels=32,out_channels=32,kernel_size=1)
        self.maxpool2 = nn.MaxPool2d(2, 2)
        #8，8，32
        self.conv3_depth = nn.Conv2d(in_channels=32,out_channels=32, kernel_size=3, padding=1,groups=32)
        self.conv3_point = nn.Conv2d(in_channels=32,out_channels=64,kernel_size=1)
        self.maxpool3 = nn.MaxPool2d(2, 2)
        self.flatten = nn.Flatten(start_dim=0)
        self.fc1 = nn.Linear(1024, 64)
        self.fc2 = nn.Linear(64, 10)

    def forward(self, x):
        x = self.conv1_depth(x)
        x = self.conv1_point(x)
        x = self.maxpool1(x)

        x = self.conv2_depth(x)
        x = self.conv2_point(x)
        x = self.maxpool2(x)

        x = self.conv3_depth(x)
        x = self.conv3_point(x)
        x = self.maxpool3(x)#64,4,4

        x = self.flatten(x)
        x = self.fc1(x)
        x = self.fc2(x)
        return x


if __name__ == '__main__':
    model = CIFAR10Model()
    input_test = torch.ones((3, 32, 32))
    output_test = model(input_test)
    print(output_test.shape)
