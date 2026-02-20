#!/usr/bin/env python
from __future__ import print_function
import argparse
import nibabel as nib
from nibabel.orientations import io_orientation, axcodes2ornt, ornt_transform, aff2axcodes

def main():
    p = argparse.ArgumentParser()
    p.add_argument('--input', required=True)
    p.add_argument('--output', required=True)
    args = p.parse_args()

    img = nib.load(args.input)
    in_ax = aff2axcodes(img.affine)
    in_ornt = io_orientation(img.affine)
    las_ornt = axcodes2ornt(('L', 'A', 'S'))
    xform = ornt_transform(in_ornt, las_ornt)
    out_img = img.as_reoriented(xform)
    nib.save(out_img, args.output)
    out_ax = aff2axcodes(out_img.affine)
    print('input_axcodes:', ''.join(in_ax))
    print('target_axcodes: LAS')
    print('output_axcodes:', ''.join(out_ax))

if __name__ == '__main__':
    main()
