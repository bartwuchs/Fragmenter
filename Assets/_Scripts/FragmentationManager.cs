using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class FragmentationManager : MonoBehaviour
{
   
    public float StartDisplacement;
    public float RestDisplacement;
    public float Randomness;
    public Texture NoiseTexture;

    public float MoveToRestTime = 3;
    public float RestTime = 10;
    public float MoveToWandTime = 1;
   
    public float TurnSpeed;
    public float Gloss;
    public Color SpecularColor;

    public static FragmentationManager Instance;

    void Awake()
    {
        Instance = this;
    }
	
}
