#include <iostream>
#include <vector>
using namespace std;


__global__ void sub_bfs(int *vertices, int *edges, int *frontier, int *distances, int *visited, int *search, int *safe , int ui, int *next_frontier, int n) {
    
  int tidx = blockIdx.x * blockDim.x + threadIdx.x;
  tidx = tidx + 1;

  if(tidx>n){
    return;
  }

  if(frontier[tidx]) {
      next_frontier[tidx] = 0;
      visited[tidx] = 1;

      for(int i=vertices[tidx] ; i<vertices[tidx+1] && *safe==0; i++) {
          if(visited[edges[i]] == 0) {
              next_frontier[edges[i]] = true; 
              *search = 1;
              if(distances[edges[i]] < distances[ui]) {*safe = 1; break;}
          }
      }
  }
  // if(cudaSuccess != cudaDeviceSynchronize()) {
  //   return;
  // }
  
}

__global__ void truncated_bfs(int src, int v, int *vertices, int *edges, int n, int *distances, int *isSafe) {
   // make a visited array
    int *visited;
    visited = (int *) (sizeof(int) * (n+2));

    // make a frontier array
    int *frontier;
    frontier = (int *) (sizeof(int) * (n+2));

    for(int i=1 ; i<=n ; i++) {
        visited[i] = 0;
        frontier[i] = 0;
    }

   // mark v as visited
    visited[v] = 1;
   // push src into the frontier
    frontier[src] = 1;

    int threadsPerBlock = 1024;
    int blocksPerGrid = (n + 1023)/1024;

    int temp1 = 0;
    int temp2 = 0;
    int *search, *safe;

    cudaMalloc((void **)&safe, sizeof(int));
    cudaMalloc((void **)&search, sizeof(int));
    *search = 1;
    *safe = 0;

    while ( (*search)==1 && (*safe) == 0) 
    { 
        *search = 0;
          sub_bfs<<<blocksPerGrid, threadsPerBlock>>>(vertices, edges, frontier, distances, visited, search, safe, src, frontier, n);
          if(cudaSuccess != cudaDeviceSynchronize()) {
            return;
          }
    }
    // if(cudaSuccess != cudaDeviceSynchronize()) {
    //   return;
    // }
    *isSafe = *safe;
}

__global__ void cut_vertex(int *vertices, int *edges, int n, int *distances, int root, int *cut_vertices) {
  int tidx = blockIdx.x * blockDim.x + threadIdx.x;
  tidx = tidx + 1;

  if(tidx >n) 
  return;

  int *isSafe;
  cudaMalloc((void **)&isSafe, sizeof(int));
  int temp = 0;
  *isSafe = 0;

  int *visited;
  cudaMalloc((void **)&visited , (sizeof(int) * (n+2)));

  // make a frontier array
  int *frontier;
  cudaMalloc((void **)&frontier , (sizeof(int) * (n+2)));

  int *next_frontier;
  cudaMalloc((void **)&next_frontier , (sizeof(int) * (n+2)));

  for(int i=vertices[tidx] ; i<vertices[tidx+1] ; i++) {
      if(distances[edges[i]] <= distances[tidx]) continue;
      int v = tidx;
      int src = edges[i];

      //truncated_bfs<<<1,1>>>(edges[i], tidx, vertices, edges, n, distances, isSafe);

      for(int i=1 ; i<=n ; i++) {
          visited[i] = 0;
          frontier[i] = 0;
          next_frontier[i] = 0;
      }

  // mark v as visited
      visited[v] = 1;
  // push src into the frontier
      frontier[src] = 1;

      int threadsPerBlock = 1024;
      int blocksPerGrid = (n + 1023)/1024;

      int temp1 = 0;
      int temp2 = 0;
      int *search, *safe;

      cudaMalloc((void **)&safe, sizeof(int));
      cudaMalloc((void **)&search, sizeof(int));
      *search = 1;
      *safe = 0;

      while ( (*search)==1 && (*safe) == 0) 
      { 
          *search = 0;
          sub_bfs<<<blocksPerGrid, threadsPerBlock>>>(vertices, edges, frontier, distances, visited, search, safe, src, next_frontier, n);
          if(cudaSuccess != cudaDeviceSynchronize()) {
            return;
          }
          for(int i=0 ; i<=n ; i++) {
              frontier[i] = next_frontier[i];
              next_frontier[i] = 0;
          }
          if(tidx == root) *safe = 0;
          // if(cudaSuccess != cudaDeviceSynchronize()) {
          //   return;
          // }
      }

      *isSafe = *safe;

      if(cudaSuccess != cudaDeviceSynchronize()) {
        return;
      }
      // if safe, continue
      // else make the status as true and break;
      if(*isSafe == 0 && tidx != root) {
        cut_vertices[tidx] = 1;
        break;
      }
  }

  if(tidx==root) {
    for(int i=vertices[root] ; i<vertices[root+1] ; i++) {
        if(visited[edges[i]] == 0) {
            cut_vertices[root] = 1;
            break;
        }
    }
  }
  // if(cudaSuccess != cudaDeviceSynchronize()) {
  //   return;
  // }
}

__global__ void bfs(int *vertices, int *edges, int n, int *distances, int *level, int *flag) {
  int tidx = blockIdx.x * blockDim.x + threadIdx.x;
  tidx = tidx + 1;

  if(tidx > n || distances[tidx] != (*level)) return;

  for(int i=vertices[tidx] ; i<vertices[tidx+1] ; i++) {
    if(distances[edges[i]] == 10000000) {
      distances[edges[i]] = *level + 1;
      *flag = 1;
    }
  }
}

int main() {
  int threadsPerBlock = 1024, blocksPerGrid;
  int n;
  cout << "enter the number of vertices\n";
  scanf("%d", &n);

  int src;
  cout << "enter the source\n";
  cin >> src;

  blocksPerGrid = (n + 1023)/1024;

  vector<vector<int>> edgeList(n);

  printf("enter the neighbours of 1 (end with a -1) followed by the neighbours of 2 (end with a -1) and so on till n\n");

  int cnt=0, edgeCnt=0;

  while(cnt < n) {
    int temp;
    cin >> temp;

    if(temp == -1) {
      cnt++;
      continue;
    }
    
    edgeCnt++;

    edgeList[cnt].push_back(temp);
  }
  cout<<"a\n";
  int *vertices, *dvertices;
  vertices = (int *) malloc(sizeof(int) * (n+2));
  cudaMalloc((void **)&dvertices, sizeof(int) * (n+2));

  int *edges, *dedges;
  edges = (int *) malloc(sizeof(int) * (edgeCnt + 2));
  cudaMalloc((void **)&dedges, sizeof(int) * (edgeCnt + 2));

  int k=1;
  for(int i=0 ; i<=n ; i++) {
    vertices[i+1] = k;
    if(i == n) break;

    for(int j=0 ; j<edgeList[i].size() ; j++) {
      edges[k++] = edgeList[i][j];
    }
  }


  int *distances, *ddistances;

  distances = (int *) malloc(sizeof(int) * (n+2));
  cudaMalloc((void **)&ddistances, sizeof(int) * (n+2));

  for(int i=1 ; i<=n ; i++) {
    distances[i] = 10000000;
  }

  distances[src] = 0;

  int *flag, *level;
  int *dflag, *dlevel;

  flag = (int *) (sizeof(int));
  level = (int *) (sizeof(int));

  cudaMalloc((void **)&dflag, sizeof(int));
  cudaMalloc((void **)&dlevel, sizeof(int));

  cudaMemcpy(ddistances, distances, (n+2) * sizeof(int), cudaMemcpyHostToDevice);
  cudaMemcpy(dvertices, vertices, (n+2) * sizeof(int), cudaMemcpyHostToDevice);
  cudaMemcpy(dedges, edges, (edgeCnt + 2) * sizeof(int), cudaMemcpyHostToDevice);

  int temp_level = 0, temp_flag = 1;

  level = &temp_level;
  flag = &temp_flag;

  cout << endl;

  while(*flag) {

    *flag = 0;
    cudaMemcpy(dflag, flag, sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(dlevel, level, sizeof(int), cudaMemcpyHostToDevice);

    bfs<<<blocksPerGrid, threadsPerBlock>>>(dvertices, dedges, n , ddistances, dlevel, dflag);
    if(cudaSuccess != cudaDeviceSynchronize()) {
      return;
    }
    *level = *level + 1;
    cudaMemcpy(flag, dflag, sizeof(int), cudaMemcpyDeviceToHost);

  }

  // if(cudaSuccess != cudaDeviceSynchronize()) {
  //   return;
  // }
  cudaMemcpy(distances, ddistances, sizeof(int) * (n+2), cudaMemcpyDeviceToHost);
  
  cout << "\ndistances array after parallel bfs\n";
  for(int i=1 ; i<=n ; i++) {
    cout << distances[i] << " ";
  }
  cout << endl;

  int *cut_vertices , *dcut_vertices;
  cut_vertices = (int *) malloc((n+2)*sizeof(int));
  cudaMalloc((void**)&dcut_vertices , (n+2)*sizeof(int));

  for(int i = 1 ; i <= n ; i++)
    cut_vertices[i] = 0;
  
  cudaMemcpy(dcut_vertices , cut_vertices , (n+2)*sizeof(int) , cudaMemcpyHostToDevice);
  cut_vertex<<<blocksPerGrid, threadsPerBlock>>>(dvertices, dedges, n, ddistances, src, dcut_vertices);
  // if(cudaSuccess != cudaDeviceSynchronize()) {
  //   return;
  // }
  cudaDeviceSynchronize();
  cudaMemcpy(cut_vertices , dcut_vertices , (n+2)*sizeof(int) , cudaMemcpyDeviceToHost);


  cout << "For each vertex i from 1 to n, prints 1 if its a cutvertex else 0\n";
  for(int i=1 ; i<=n ; i++) {
    cout << cut_vertices[i] << " ";
  }
  cout << endl;

  cout << endl;
  return 0;
}

// ex: 2 3 -1 1 4 5 -1 1 6 7 -1 2 5 8 -1 2 4 9 -1 3 -1 3 -1 4 -1 5 10 -1 9 -1
// 2 3 -1 1 3 6 -1 1 2 6 4 5 -1 3 12 13 -1 3 6 -1 2 3 5 7 8 -1 6 8 -1 6 7 9 11 -1 8 11 -1 11 -1 8 9 10 -1 4 13 14 -1 4 12 14 -1 12 13 15 -1 13 14 16 17 -1 15 17 -1 15 16 -1